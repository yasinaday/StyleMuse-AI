"""Private StyleMuse API; disabled unless explicitly configured."""
import os
import secrets
from dataclasses import dataclass
import base64
import hashlib
import json
import time
from io import BytesIO
from PIL import Image, ImageOps
from math import sqrt
from pydantic import BaseModel, Field, ConfigDict
from store import Store, units

class GenerateRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    job_id: str = Field(min_length=1,max_length=128)
    item_ids: list[str] = Field(min_length=1,max_length=20)
    confirmed: bool = Field(default=False, strict=True)
    max_total_usd: float = Field(default=0,ge=0,allow_inf_nan=False)

class DetectRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    image: str
    request_id: str = Field(min_length=1, max_length=128, pattern=r'^[a-zA-Z0-9_-]+$')
    confirmed: bool = Field(default=False, strict=True)
    max_total_usd: float = Field(default=0, ge=0, allow_inf_nan=False)

def normalize(uri, s, *, preserve_alpha=False, upload=False):
    try:
        if not isinstance(uri, str) or not uri.startswith(('data:image/png;base64,', 'data:image/jpeg;base64,')):
            raise ValueError()
        if len(uri) > s.max_image_bytes*4//3+100:
            raise ValueError()
        raw = base64.b64decode(uri.split(',', 1)[1], validate=True)
        if len(raw) > s.max_image_bytes:
            raise ValueError()
        with Image.open(BytesIO(raw)) as im:
            if im.format not in ('PNG', 'JPEG') or im.width*im.height > s.max_pixels:
                raise ValueError()
            im.load()
            if upload:
                # Normalize once before hashing, storing, or detecting: masks and
                # later generation references share this exact coordinate space.
                im = ImageOps.exif_transpose(im)
                limit = 1_048_576
                if im.width * im.height > limit:
                    scale = sqrt(limit / (im.width * im.height))
                    size = (max(1, min(limit, int(im.width * scale))),
                            max(1, min(limit, int(im.height * scale))))
                    im = im.resize(size, Image.Resampling.LANCZOS)
            b = BytesIO()
            im.convert('RGBA' if preserve_alpha else 'RGB').save(b, 'PNG')
        if len(b.getvalue()) > s.max_image_bytes:
            raise ValueError()
        return 'data:image/png;base64,'+base64.b64encode(b.getvalue()).decode()
    except Exception:
        raise HTTPException(422, 'invalid_image') from None
from fastapi import FastAPI, Header, HTTPException, Request
from threading import Lock
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from starlette.responses import JSONResponse

class BoundedBody:
    def __init__(self, app, limit):
        self.app, self.limit = app, limit
    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            return await self.app(scope,receive,send)
        chunks = []
        total = 0
        while True:
            message = await receive()
            if message['type'] == 'http.disconnect':
                return
            chunk = message.get('body', b'')
            total += len(chunk)
            if total > self.limit:
                return await JSONResponse({'error':'request_too_large'},status_code=413)(scope,receive,send)
            chunks.append(chunk)
            if not message.get('more_body',False):
                break
        async def replay():
            return {'type':'http.request','body':b''.join(chunks),'more_body':False}
        await self.app(scope,replay,send)

def public_result(jid, items):
    return {'job_id':jid, 'items':[{k:i[k] for k in ('id','preview','category')} for i in items]}

@dataclass
class Settings:
    access_token: str = ''
    origin: str = 'https://yasinaday.github.io'
    enabled: bool = False
    lifetime_budget_usd: float = 0
    detect_reservation_usd: float = .05
    generation_reservation_usd: float = .1
    db_path: str = '/var/lib/stylemuse/state.sqlite'
    storage_dir: str = '/var/lib/stylemuse/images'
    max_storage_bytes: int = 134217728
    session_ttl_seconds: int = 86400
    max_sessions: int = 1024
    max_request_bytes: int = 9000000
    max_image_bytes: int = 6291456
    max_pixels: int = 16000000

    @classmethod
    def from_env(cls):
        import math
        from dataclasses import fields
        settings = cls()
        for field in fields(cls):
            value = os.environ.get('STYLEMUSE_' + field.name.upper())
            if value is None:
                continue
            try:
                if field.type is bool:
                    if value not in ('true', 'false'):
                        raise ValueError()
                    value = value == 'true'
                else:
                    value = field.type(value)
                if field.type in (int, float):
                    if not math.isfinite(value) or value < 0 or (field.name != 'lifetime_budget_usd' and value == 0):
                        raise ValueError()
            except (ValueError, OverflowError):
                raise ValueError('Invalid STYLEMUSE_' + field.name.upper()) from None
            setattr(settings, field.name, value)
        return settings

def create_app(settings=None, provider=None):
    s = Settings(**settings) if isinstance(settings, dict) else (settings or Settings())
    from urllib.parse import urlsplit
    origin = urlsplit(s.origin)
    if (origin.scheme not in ('http', 'https') or not origin.hostname
            or origin.username is not None or origin.password is not None
            or origin.path or origin.query or origin.fragment or '*' in s.origin
            or s.origin != f'{origin.scheme}://{origin.netloc}'):
        raise ValueError('STYLEMUSE_ORIGIN must be one exact HTTP(S) origin')
    if any(type(value) is not int or value <= 0
           for value in (s.max_sessions, s.session_ttl_seconds)):
        raise ValueError('Session capacity and TTL must be positive finite integers')
    store = Store(s)
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    app.add_middleware(BoundedBody, limit=s.max_request_bytes)
    @app.exception_handler(RequestValidationError)
    async def validation_error(request, exc):
        return JSONResponse({'error':'invalid_request'},status_code=422)
    @app.exception_handler(HTTPException)
    async def known_error(request, exc):
        return JSONResponse({'error':exc.detail},status_code=exc.status_code)
    @app.exception_handler(Exception)
    async def internal_error(request, exc):
        return JSONResponse({'error':'internal_error'},status_code=500)
    app.add_middleware(CORSMiddleware, allow_origins=[s.origin], allow_credentials=True, allow_methods=['GET', 'POST'], allow_headers=['Authorization', 'Content-Type'])
    # Opaque tokens remain server-side and are never an inference capability.
    sessions = {}
    session_lock = Lock()
    cookie_name = '__Host-stylemuse_session'

    def exact_origin(request):
        if request.headers.getlist('origin') != [s.origin] or s.origin in ('', '*', 'null'):
            raise HTTPException(403, 'origin_not_allowed')

    @app.post('/api/session')
    def session(request: Request):
        exact_origin(request)
        with session_lock:
            now = time.monotonic()
            for expired in [key for key, entry in sessions.items() if entry[1] <= now]:
                del sessions[expired]
            token = request.cookies.get(cookie_name, '')
            if token not in sessions:
                if len(sessions) >= s.max_sessions:
                    raise HTTPException(429, 'session_capacity_reached')
                token = secrets.token_urlsafe(32)
                sessions[token] = (secrets.token_urlsafe(32), now + s.session_ttl_seconds)
            remaining = max(1, int(sessions[token][1] - now))
        response = JSONResponse({'status': 'ok', 'enabled': s.enabled})
        cookie_options = dict(key=cookie_name, value=token, max_age=remaining,
                              secure=True, httponly=True, samesite='none', path='/')
        try:
            response.set_cookie(**cookie_options, partitioned=True)
        except (TypeError, ValueError):
            # Older Starlette/Python versions cannot emit Partitioned.
            response.set_cookie(**cookie_options)
            # CHIPS is a wire attribute; emit safely even on older Python.
            response.headers['set-cookie'] += '; Partitioned'
        response.headers['Cache-Control'] = 'no-store'
        return response

    def owner(authorization, request, *, paid=False):
        if s.access_token and secrets.compare_digest((authorization or '').encode(), ('Bearer '+s.access_token).encode()):
            return hashlib.sha256(s.access_token.encode()).hexdigest()
        token = request.cookies.get(cookie_name, '')
        with session_lock:
            entry = sessions.get(token)
            if entry and entry[1] > time.monotonic():
                exact_origin(request)
                if paid:
                    raise HTTPException(403, 'paid_inference_not_authorized')
                return entry[0]
        raise HTTPException(401, 'unauthorized')
    @app.get('/api/health')
    def public_health():
        return {'status': 'ok', 'enabled': s.enabled}

    @app.post('/api/health')
    def health(request: Request, authorization: str | None = Header(None)):
        owner(authorization, request)
        return {'status':'ok', 'enabled':s.enabled, **store.costs()}
    @app.post('/api/detect')
    def detect(payload: DetectRequest, request: Request, authorization: str | None = Header(None)):
        who = owner(authorization, request, paid=True)
        if not s.enabled or provider is None:
            raise HTTPException(503, 'inference_disabled')
        if not payload.confirmed or units(payload.max_total_usd) < units(s.detect_reservation_usd):
            raise HTTPException(403, 'cost_confirmation_required')
        original = normalize(payload.image, s, upload=True)
        digest = hashlib.sha256(original.encode()).hexdigest()
        jid = secrets.token_urlsafe(24)
        with store.tx() as db:
            row = db.execute('SELECT * FROM jobs WHERE owner=? AND request_id=?', (who,payload.request_id)).fetchone()
            if row:
                if row['hash'] != digest or row['state'] != 'done' or row['expires'] < time.time():
                    raise HTTPException(409, 'request_already_claimed')
                result = json.loads(row['result'])
                return public_result(row['id'], result)
            store.capacity(db,len(original))
            store.reserve(db, units(s.detect_reservation_usd))
            db.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?)', (jid,who,payload.request_id,digest,'claimed',original,None,time.time()+s.session_ttl_seconds))
        try:
            items = provider.detect(original)
            if not isinstance(items,list) or not 1 <= len(items) <= 20:
                raise ValueError()
            result = []
            for item in items:
                if not isinstance(item.get('category'),str) or not 1 <= len(item['category']) <= 100 or not isinstance(item.get('prompt'),str) or len(item['prompt']) > 4000:
                    raise ValueError()
                result.append(dict(id=secrets.token_urlsafe(24), category=item['category'], preview=normalize(item['preview'],s,preserve_alpha=True), prompt=item['prompt']))
            with store.tx() as db:
                store.capacity(db,len(json.dumps(result)))
                db.execute('UPDATE jobs SET state=?,result=? WHERE id=?', ('done',json.dumps(result),jid))
            return public_result(jid,result)
        except Exception:
            raise HTTPException(502, 'provider_failed_no_retry') from None
        finally:
            store.release()
    @app.post('/api/generate')
    def generate(payload: GenerateRequest, request: Request, authorization: str | None = Header(None)):
        who = owner(authorization, request, paid=True)
        if not s.enabled or provider is None:
            raise HTTPException(503, 'inference_disabled')
        if not payload.confirmed or len(set(payload.item_ids)) != len(payload.item_ids):
            raise HTTPException(403, 'cost_confirmation_required')
        with store.tx() as db:
            job = db.execute('SELECT * FROM jobs WHERE id=? AND owner=?', (payload.job_id,who)).fetchone()
            if not job or job['state'] != 'done' or job['expires'] < time.time():
                raise HTTPException(404,'job_not_found')
            available = {i['id']:i for i in json.loads(job['result'])}
            if any(i not in available for i in payload.item_ids):
                raise HTTPException(404,'item_not_found')
            old = {r['item']:r for r in db.execute('SELECT * FROM claims WHERE job=?',(payload.job_id,))}
            if any(i in old and old[i]['state'] != 'done' for i in payload.item_ids):
                raise HTTPException(409,'generation_already_claimed')
            pending = [i for i in payload.item_ids if i not in old]
            cost = units(s.generation_reservation_usd)*len(pending)
            if units(payload.max_total_usd) < cost:
                raise HTTPException(403,'cost_confirmation_required')
            if pending:
                store.capacity(db,len(pending)*(s.max_image_bytes*4//3+100))
                store.reserve(db,cost)
                for i in pending:
                    db.execute('INSERT INTO claims VALUES(?,?,?,NULL)',(payload.job_id,i,'claimed'))
        if not pending:
            return {'items':[{'id':i,'image':old[i]['image']} for i in payload.item_ids]}
        try:
            for i in pending:
                result = normalize(provider.generate(job['original'],available[i]),s)
                with store.tx() as db:
                    db.execute('UPDATE claims SET state=?,image=? WHERE job=? AND item=?',('done',result,payload.job_id,i))
            with store.tx() as db:
                results = {r['item']:r['image'] for r in db.execute('SELECT * FROM claims WHERE job=?',(payload.job_id,))}
            return {'items':[{'id':i,'image':results[i]} for i in payload.item_ids]}
        except Exception:
            raise HTTPException(502,'provider_failed_no_retry') from None
        finally:
            store.release()
    return app

def create_app_from_env():
    """Construct locally; configuration is not permission to submit inference."""
    settings = Settings.from_env()
    provider = None
    if settings.enabled and settings.access_token and settings.lifetime_budget_usd > 0:
        from providers import RealProviders
        provider = RealProviders.from_env()
    return create_app(settings, provider)


app = create_app_from_env()