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
from providers import is_footwear

class GenerateRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    job_id: str = Field(min_length=1,max_length=128)
    quote_id: str = Field(default='', max_length=128)
    item_ids: list[str] = Field(min_length=1,max_length=20)
    confirmed: bool = Field(default=False, strict=True)
    max_total_usd: float = Field(default=0,ge=0,allow_inf_nan=False)

class DetectRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    image: str
    quote_id: str = Field(default='', max_length=128)
    request_id: str = Field(min_length=1, max_length=128, pattern=r'^[a-zA-Z0-9_-]+$')
    confirmed: bool = Field(default=False, strict=True)
    max_total_usd: float = Field(default=0, ge=0, allow_inf_nan=False)

class TryOnRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    person_image: str
    clothing_image: str
    request_id: str = Field(min_length=1, max_length=100, pattern=r'^[a-zA-Z0-9_-]+$')
    quote_id: str = Field(default='', max_length=128)
    confirmed: bool = Field(default=False, strict=True)
    max_total_usd: float = Field(default=0, ge=0, allow_inf_nan=False)

class TryOnStatus(BaseModel):
    model_config = ConfigDict(extra='forbid')
    job_id: str = Field(min_length=1, max_length=128)

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

def quality_fields(item):
    """Bounded public diagnostics, never a provider payload or semantic verdict."""
    quality = item.get('mask_quality', {'status': 'missing', 'source': 'unavailable'})
    warnings = item.get('quality_warnings', ['semantic_category_unverified', 'mask_quality_unavailable'])
    if item.get('category_verified', False) is not False:
        raise ValueError('Unsupported semantic verification claim')
    allowed_warnings = {'semantic_category_unverified', 'mask_completeness_unverified',
                        'mask_quality_unavailable', 'small_mask', 'image_boundary_contact'}
    if (not isinstance(warnings, list) or len(warnings) > 5 or
            any(not isinstance(w, str) or w not in allowed_warnings for w in warnings)):
        raise ValueError('Invalid quality warnings')
    if not isinstance(quality, dict) or quality.get('status') not in ('unverified', 'review_required', 'missing'):
        raise ValueError('Invalid mask quality')
    if quality.get('source') not in ('detector_mask', 'unavailable'):
        raise ValueError('Invalid mask source')
    safe = {k: quality[k] for k in ('status', 'source')}
    for key, size in (('bbox', 4), ('image_size', 2)):
        if key in quality:
            value = quality[key]
            if (not isinstance(value, list) or len(value) != size or
                    any(type(n) is not int or not 0 <= n <= 1_048_576 for n in value)):
                raise ValueError('Invalid mask geometry')
            safe[key] = value
    if 'foreground_pixels' in quality:
        area = quality['foreground_pixels']
        if type(area) is not int or not 0 < area <= 1_048_576:
            raise ValueError('Invalid mask area')
        safe['foreground_pixels'] = area
    if 'detector_score' in quality:
        score = quality['detector_score']
        if type(score) not in (int, float) or not 0 <= score <= 1:
            raise ValueError('Invalid detector score')
        safe['detector_score'] = score
    return dict(mask_quality=safe, quality_warnings=list(warnings), category_verified=False)


def public_result(jid, items):
    return {'job_id':jid, 'items':[dict({k:i[k] for k in ('id','preview','category')},
                                     **quality_fields(i)) for i in items if not is_footwear(i.get('category'))]}

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
    github_client_id: str = ''
    github_client_secret: str = ''
    github_owner_id: str = ''
    github_owner_login: str = ''
    github_redirect_uri: str = ''
    github_return_url: str = ''
    oauth_state_ttl_seconds: int = 600
    owner_lifetime_budget_usd: float = .5
    owner_rate_limit: int = 3
    owner_rate_window_seconds: int = 60

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

def oauth_http_client():
    import httpx
    return httpx.Client(timeout=15, follow_redirects=False, trust_env=False)


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
    if any(type(value) is not int or value <= 0
           for value in (s.owner_rate_limit, s.owner_rate_window_seconds)):
        raise ValueError('Owner rate limit and window must be positive integers')
    units(s.owner_lifetime_budget_usd)
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

    oauth_states = {}
    oauth_active = {}
    authorized = {}

    def oauth_configured():
        from urllib.parse import urlsplit
        callback, target = urlsplit(s.github_redirect_uri), urlsplit(s.github_return_url)
        return (all((s.github_client_id, s.github_client_secret, s.github_owner_id,
                     s.github_owner_login, s.github_redirect_uri, s.github_return_url))
                and s.github_owner_id.isascii() and s.github_owner_id.isdecimal()
                and int(s.github_owner_id) > 0 and str(int(s.github_owner_id)) == s.github_owner_id
                and callback.scheme == 'https' and callback.hostname
                and not callback.username and not callback.password
                and callback.path == '/api/auth/github/callback'
                and not callback.query and not callback.fragment
                and target.scheme == 'https' and target.netloc == origin.netloc
                and not target.username and not target.password and not target.fragment
                and type(s.oauth_state_ttl_seconds) is int and 0 < s.oauth_state_ttl_seconds <= 600)

    if s.enabled and (s.github_owner_id or s.github_owner_login) and not oauth_configured():
        raise ValueError('Complete pinned GitHub OAuth configuration required when enabled')
    store = Store(s)

    def identity_status(token):
        identity = authorized.get(token)
        return {'authenticated': identity is not None, 'identity': identity}

    @app.middleware('http')
    async def private_cache(request, call_next):
        response = await call_next(request)
        response.headers['Cache-Control'] = 'no-store'
        response.headers['Referrer-Policy'] = 'no-referrer'
        return response

    @app.post('/api/auth/github/start')
    def github_start(request: Request):
        from urllib.parse import urlencode
        exact_origin(request)
        if not oauth_configured():
            raise HTTPException(503, 'oauth_not_configured')
        token = request.cookies.get(cookie_name, '')
        with session_lock:
            now = time.monotonic()
            entry = sessions.get(token)
            if not entry or entry[1] <= now:
                raise HTTPException(401, 'unauthorized')
            for key in [key for key, value in oauth_states.items()
                        if value[2] <= now or value[0] == token]:
                del oauth_states[key]
            if len(oauth_states) >= s.max_sessions:
                raise HTTPException(429, 'oauth_capacity_reached')
            state, verifier = secrets.token_urlsafe(32), secrets.token_urlsafe(48)
            oauth_active[token] = state
            oauth_states[state] = (token, verifier, min(entry[1], now + s.oauth_state_ttl_seconds),
                                   {'phase': 'launch'})
        return {'launch_url': s.github_redirect_uri.rsplit('/', 1)[0] + '/launch?' + urlencode({'ticket': state})}

    def oauth_ticket(request, phase):
        tickets = request.query_params.getlist('ticket')
        state = tickets[0] if len(tickets) == 1 else ''
        entry = oauth_states.get(state)
        if (not entry or entry[2] <= time.monotonic() or entry[3]['phase'] != phase
                or entry[0] not in sessions or sessions[entry[0]][1] <= time.monotonic()):
            raise HTTPException(403, 'oauth_state_invalid')
        return state, entry

    @app.get('/api/auth/github/launch')
    def github_launch(request: Request):
        from starlette.responses import RedirectResponse
        from urllib.parse import urlencode
        with session_lock:
            state, entry = oauth_ticket(request, 'launch')
            proof, handoff = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
            entry[3].update(phase='handoff', proof=proof, handoff=handoff)
            response = RedirectResponse(s.github_return_url + '#' + urlencode({'oauth_handoff': handoff}), status_code=303)
            response.set_cookie('__Host-stylemuse_oauth_browser', proof,
                secure=True, httponly=True, samesite='lax', path='/', max_age=s.oauth_state_ttl_seconds)
            return response

    @app.post('/api/auth/github/handoff')
    async def github_handoff(request: Request):
        from urllib.parse import urlencode
        exact_origin(request)
        try:
            payload = await request.json()
            handoff = payload.get('handoff') if isinstance(payload, dict) else None
        except Exception:
            handoff = None
        if not isinstance(handoff, str) or not 1 <= len(handoff) <= 128:
            raise HTTPException(403, 'oauth_handoff_invalid')
        token = request.cookies.get(cookie_name, '')
        with session_lock:
            for state, entry in oauth_states.items():
                meta = entry[3]
                if (entry[0] == token and entry[2] > time.monotonic()
                        and meta['phase'] == 'handoff'
                        and secrets.compare_digest(meta['handoff'], handoff)
                        and token in sessions and sessions[token][1] > time.monotonic()):
                    meta['phase'] = 'authorize'
                    del meta['handoff']
                    return {'authorization_url': s.github_redirect_uri.rsplit('/', 1)[0] + '/authorize?' + urlencode({'ticket': state})}
        raise HTTPException(403, 'oauth_handoff_invalid')

    @app.get('/api/auth/github/authorize')
    def github_authorize(request: Request):
        from starlette.responses import RedirectResponse
        from urllib.parse import urlencode
        with session_lock:
            state, entry = oauth_ticket(request, 'authorize')
            if not secrets.compare_digest(request.cookies.get('__Host-stylemuse_oauth_browser', ''), entry[3]['proof']):
                raise HTTPException(403, 'oauth_browser_invalid')
            entry[3]['phase'] = 'callback'
            verifier = entry[1]
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b'=').decode()
        return RedirectResponse('https://github.com/login/oauth/authorize?' + urlencode({
            'client_id': s.github_client_id, 'redirect_uri': s.github_redirect_uri,
            'state': state, 'code_challenge': challenge, 'code_challenge_method': 'S256',
            'scope': ''}), status_code=303)

    @app.get('/api/auth/github/callback')
    def github_callback(request: Request):
        from starlette.responses import RedirectResponse
        if not oauth_configured():
            raise HTTPException(503, 'oauth_not_configured')
        # State/PKCE alone do not identify the browser that approved consent.
        # Only the proof-bearing browser can consume its transaction.
        states = request.query_params.getlist('state')
        with session_lock:
            entry = oauth_states.get(states[0]) if len(states) == 1 else None
            if (not entry or entry[2] <= time.monotonic() or entry[3]['phase'] != 'callback'
                    or not secrets.compare_digest(request.cookies.get('__Host-stylemuse_oauth_browser', ''), entry[3]['proof'])):
                raise HTTPException(403, 'oauth_state_invalid')
            del oauth_states[states[0]]
            token, verifier, deadline, _ = entry
            session_entry = sessions.get(token)
            if not session_entry or session_entry[1] <= time.monotonic():
                raise HTTPException(403, 'oauth_state_invalid')
        codes = request.query_params.getlist('code')
        if request.query_params.get('error') or len(codes) != 1 or not 1 <= len(codes[0]) <= 1024:
            raise HTTPException(403, 'oauth_denied')
        try:
            with oauth_http_client() as client:
                response = client.post('https://github.com/login/oauth/access_token',
                    headers={'Accept': 'application/json'}, data={
                        'client_id': s.github_client_id, 'client_secret': s.github_client_secret,
                        'redirect_uri': s.github_redirect_uri, 'code': codes[0],
                        'code_verifier': verifier})
                response.raise_for_status()
                access = response.json()['access_token']
                if not isinstance(access, str) or not access:
                    raise ValueError()
                response = client.get('https://api.github.com/user', headers={
                    'Authorization': 'Bearer ' + access, 'Accept': 'application/vnd.github+json',
                    'X-GitHub-Api-Version': '2022-11-28'})
                response.raise_for_status()
                user = response.json()
                if not isinstance(user, dict):
                    raise ValueError()
        except Exception:
            raise HTTPException(502, 'oauth_provider_failed') from None
        if (type(user.get('id')) is not int or str(user['id']) != s.github_owner_id
                or not isinstance(user.get('login'), str)
                or user['login'].casefold() != s.github_owner_login.casefold()):
            raise HTTPException(403, 'oauth_account_not_allowed')
        with session_lock:
            session_entry = sessions.get(token)
            if (not session_entry or session_entry[1] <= time.monotonic()
                    or deadline <= time.monotonic() or oauth_active.get(token) != states[0]):
                raise HTTPException(403, 'oauth_state_invalid')
            oauth_active.pop(token, None)
            authorized[token] = {'provider': 'github', 'id': s.github_owner_id,
                                 'login': s.github_owner_login}
        return RedirectResponse(s.github_return_url, status_code=303)

    @app.post('/api/auth/logout')
    def logout(request: Request):
        exact_origin(request)
        token = request.cookies.get(cookie_name, '')
        with session_lock:
            sessions.pop(token, None)
            oauth_active.pop(token, None)
            authorized.pop(token, None)
            for state in [key for key, entry in oauth_states.items() if entry[0] == token]:
                del oauth_states[state]
        response = JSONResponse({'status': 'ok', 'authenticated': False, 'identity': None})
        response.set_cookie(cookie_name, '', max_age=0, secure=True, httponly=True,
                            samesite='none', path='/')
        response.headers['set-cookie'] += '; Partitioned'
        return response

    @app.post('/api/session')
    def session(request: Request):
        exact_origin(request)
        with session_lock:
            now = time.monotonic()
            for expired in [key for key, entry in sessions.items() if entry[1] <= now]:
                del sessions[expired]
                oauth_active.pop(expired, None)
                authorized.pop(expired, None)
            token = request.cookies.get(cookie_name, '')
            if token not in sessions:
                if len(sessions) >= s.max_sessions:
                    raise HTTPException(429, 'session_capacity_reached')
                token = secrets.token_urlsafe(32)
                sessions[token] = (secrets.token_urlsafe(32), now + s.session_ttl_seconds)
            remaining = max(1, int(sessions[token][1] - now))
        response = JSONResponse({'status': 'ok', 'enabled': s.enabled,
                                 **(identity_status(token) if s.github_owner_id else {})})
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
        if not paid and not s.github_owner_id and not s.github_owner_login and s.access_token and secrets.compare_digest((authorization or '').encode(), ('Bearer '+s.access_token).encode()):
            return hashlib.sha256(s.access_token.encode()).hexdigest()
        token = request.cookies.get(cookie_name, '')
        with session_lock:
            entry = sessions.get(token)
            if entry and entry[1] > time.monotonic():
                exact_origin(request)
                if token in authorized:
                    return 'github:' + authorized[token]['id']
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
        return {'status':'ok', 'enabled':s.enabled, **store.costs(),
                'app_spending_ceiling_usd': None, 'historical_budget_metadata': True,
                **(identity_status(request.cookies.get(cookie_name, '')) if s.github_owner_id else {})}
    def credit_preflight(action, cost):
        from decimal import Decimal
        import math
        try:
            balance = provider.credit_available_usd(action)
        except Exception:
            balance = None
        credit = None
        if balance is None and action == 'detect':
            try:
                credit = store.manual_credit(provider.replicate_account())
                balance = credit['available_usd'] if credit else None
            except Exception:
                balance = None
        if type(balance) not in (int, float, Decimal) or not math.isfinite(balance) or balance < 0:
            raise HTTPException(402, 'provider_credit_unavailable')
        if Decimal(str(balance)) * 1000000 < cost:
            raise HTTPException(402, 'provider_credit_insufficient')
        return credit or {'source': 'provider_api', 'available_usd': float(balance), 'overspend_risk': True}

    def quote_digest(action, inputs, credit=None):
        return hashlib.sha256(json.dumps({'action': action, 'inputs': inputs,
            'manual_snapshot': (credit or {}).get('snapshot_id')},
            sort_keys=True, separators=(',', ':')).encode()).hexdigest()

    def before_paid_submit(operation, action, cost):
        credit = credit_preflight(action, cost)
        store.mark_submitted(operation, manual_credit_id=credit.get('snapshot_id'))

    def consume_quote(db, payload, request, who, action, inputs, cost, credit=None):
        from decimal import Decimal
        if not payload.confirmed or Decimal(str(payload.max_total_usd)) * 1000000 != cost:
            raise HTTPException(403, 'cost_confirmation_required')
        if credit and credit.get('snapshot_id'):
            current = store._manual_credit(db, credit['account'])
            if not current or current['snapshot_id'] != credit['snapshot_id']:
                raise HTTPException(403, 'quote_invalid_or_expired')
        row = db.execute('SELECT * FROM payment_quotes WHERE id=?', (payload.quote_id,)).fetchone()
        if (not row or row['used'] or row['expires'] <= time.time()
                or row['owner'] != who or row['session'] != request.cookies.get(cookie_name, '')
                or row['digest'] != quote_digest(action, inputs, credit) or row['amount'] != cost):
            raise HTTPException(403, 'quote_invalid_or_expired')
        db.execute('UPDATE payment_quotes SET used=1 WHERE id=?', (payload.quote_id,))

    @app.post('/api/quote')
    async def quote(request: Request, authorization: str | None = Header(None)):
        who = owner(authorization, request, paid=True)
        if not s.enabled or provider is None:
            raise HTTPException(503, 'inference_disabled')
        try:
            body = await request.json()
            if set(body) != {'action', 'inputs'} or body['action'] not in ('detect', 'generate', 'tryon'):
                raise ValueError()
            action = body['action']
            payload = {'detect': DetectRequest, 'generate': GenerateRequest, 'tryon': TryOnRequest}[action].model_validate(body['inputs'])
            if payload.confirmed or payload.quote_id or payload.max_total_usd:
                raise ValueError()
        except Exception:
            raise HTTPException(422, 'invalid_request') from None
        if action == 'tryon':
            normalize(payload.person_image, s, upload=True)
            normalize(payload.clothing_image, s, preserve_alpha=True, upload=True)
            inputs = tryon_inputs(payload)
            cost = 40000  # fal official price: one output image, $0.04.
        elif action == 'detect':
            normalize(payload.image, s, upload=True)
            inputs = {'image': payload.image, 'request_id': payload.request_id}
            cost = units(s.detect_reservation_usd)
        else:
            if len(set(payload.item_ids)) != len(payload.item_ids):
                raise HTTPException(422, 'invalid_request')
            with store.tx() as db:
                job = db.execute('SELECT * FROM jobs WHERE id=? AND owner=?', (payload.job_id, who)).fetchone()
                if not job or job['request_id'].startswith('tryon:') or job['state'] != 'done' or job['expires'] <= time.time():
                    raise HTTPException(404, 'job_not_found')
                available = {i['id'] for i in json.loads(job['result']) if not is_footwear(i.get('category'))}
                if any(i not in available for i in payload.item_ids):
                    raise HTTPException(404, 'item_not_found')
                old = {r['item']: r for r in db.execute('SELECT * FROM claims WHERE job=?', (payload.job_id,))}
                if any(i in old and old[i]['state'] != 'done' for i in payload.item_ids):
                    raise HTTPException(409, 'generation_already_claimed')
                cost = units(s.generation_reservation_usd) * sum(i not in old for i in payload.item_ids)
                inputs = generation_quote_inputs(payload, job)
        credit = credit_preflight(action, cost) if cost else None
        qid = secrets.token_urlsafe(32)
        with store.tx() as db:
            db.execute('INSERT INTO payment_quotes VALUES(?,?,?,?,?,?,?,0)',
                (qid, who, request.cookies.get(cookie_name, ''), quote_digest(action, inputs, credit),
                 cost, time.time() + 90, action))
        return {'quote_id': qid, 'action': action, 'estimated_cost_usd': cost/1000000,
                'expires_in_seconds': 90, 'provider_credit': credit, 'app_spending_ceiling_usd': None}

    def generation_quote_inputs(payload, job):
        return {'job_id': payload.job_id, 'item_ids': payload.item_ids,
                'source_hash': hashlib.sha256(job['original'].encode()).hexdigest(), 'result_hash': hashlib.sha256(job['result'].encode()).hexdigest()}

    @app.post('/api/detect')
    def detect(payload: DetectRequest, request: Request, authorization: str | None = Header(None)):
        who = owner(authorization, request, paid=True)
        if not s.enabled or provider is None:
            raise HTTPException(503, 'inference_disabled')
        if not payload.confirmed or units(payload.max_total_usd) < units(s.detect_reservation_usd):
            raise HTTPException(403, 'cost_confirmation_required')
        original = normalize(payload.image, s, upload=True)
        credit = credit_preflight('detect', units(s.detect_reservation_usd))
        digest = hashlib.sha256(original.encode()).hexdigest()
        jid = secrets.token_urlsafe(24)
        with store.tx() as db:
            consume_quote(db, payload, request, who, 'detect',
                          {'image': payload.image, 'request_id': payload.request_id}, units(s.detect_reservation_usd), credit)
            row = db.execute('SELECT * FROM jobs WHERE owner=? AND request_id=?', (who,payload.request_id)).fetchone()
            if row:
                if row['hash'] != digest or row['state'] != 'done' or row['expires'] < time.time():
                    raise HTTPException(409, 'request_already_claimed')
                result = json.loads(row['result'])
                return public_result(row['id'], result)
            store.capacity(db,len(original))
            store.reserve(db, units(s.detect_reservation_usd), owner=who, enforce_budget=False)
            store.record_operation(db, 'detect:' + jid, units(s.detect_reservation_usd), who if who.startswith('github:') else None)
            db.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?)', (jid,who,payload.request_id,digest,'claimed',original,None,time.time()+s.session_ttl_seconds))
        try:
            from providers import RealProviders
            if type(provider) is RealProviders:
                items = provider.detect(original, before_submit=lambda: before_paid_submit('detect:' + jid, 'detect', units(s.detect_reservation_usd)))
            else:
                # Unknown adapters provide no proof of non-submission.
                before_paid_submit('detect:' + jid, 'detect', units(s.detect_reservation_usd))
                items = provider.detect(original)
            if not isinstance(items,list) or not 0 <= len(items) <= 20:
                raise ValueError()
            result = []
            for item in items:
                if is_footwear(item.get('category')):
                    continue
                if not isinstance(item.get('category'),str) or not 1 <= len(item['category']) <= 100 or not isinstance(item.get('prompt'),str) or len(item['prompt']) > 4000:
                    raise ValueError()
                result.append(dict(id=secrets.token_urlsafe(24), category=item['category'], preview=normalize(item['preview'],s,preserve_alpha=True), prompt=item['prompt'], **quality_fields(item)))
            with store.tx() as db:
                store.capacity(db,len(json.dumps(result)))
                db.execute('UPDATE jobs SET state=?,result=? WHERE id=?', ('done',json.dumps(result),jid))
            store.finish_operation('detect:' + jid, success=True)
            return public_result(jid,result)
        except BaseException as exc:
            store.finish_operation('detect:' + jid, success=False)
            if not isinstance(exc, Exception):
                raise
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
            if not job or job['request_id'].startswith('tryon:') or job['state'] != 'done' or job['expires'] < time.time():
                raise HTTPException(404,'job_not_found')
            available = {i['id']:i for i in json.loads(job['result']) if not is_footwear(i.get('category'))}
            if any(i not in available for i in payload.item_ids):
                raise HTTPException(404,'item_not_found')
            old = {r['item']:r for r in db.execute('SELECT * FROM claims WHERE job=?',(payload.job_id,))}
            if any(i in old and old[i]['state'] != 'done' for i in payload.item_ids):
                raise HTTPException(409,'generation_already_claimed')
            pending = [i for i in payload.item_ids if i not in old]
            cost = units(s.generation_reservation_usd)*len(pending)
            consume_quote(db, payload, request, who, 'generate', generation_quote_inputs(payload, job), cost)
            if pending:
                credit_preflight('generate', cost)
                store.capacity(db,len(pending)*(s.max_image_bytes*4//3+100))
                store.reserve(db,cost, owner=who, enforce_budget=False)
                for i in pending:
                    store.record_operation(db, 'generate:' + payload.job_id + ':' + i, units(s.generation_reservation_usd), who if who.startswith('github:') else None)
                    db.execute('INSERT INTO claims VALUES(?,?,?,NULL)',(payload.job_id,i,'claimed'))
        if not pending:
            return {'items':[{'id':i,'image':old[i]['image']} for i in payload.item_ids]}
        try:
            for i in pending:
                from providers import RealProviders
                operation = 'generate:' + payload.job_id + ':' + i
                if type(provider) is RealProviders:
                    generated = provider.generate(job['original'], available[i], before_submit=lambda: before_paid_submit(operation, 'generate', units(s.generation_reservation_usd)))
                else:
                    before_paid_submit(operation, 'generate', units(s.generation_reservation_usd))
                    generated = provider.generate(job['original'], available[i])
                result = normalize(generated,s)
                with store.tx() as db:
                    db.execute('UPDATE claims SET state=?,image=? WHERE job=? AND item=?',('done',result,payload.job_id,i))
                store.finish_operation(operation, success=True)
            with store.tx() as db:
                results = {r['item']:r['image'] for r in db.execute('SELECT * FROM claims WHERE job=?',(payload.job_id,))}
            return {'items':[{'id':i,'image':results[i]} for i in payload.item_ids]}
        except BaseException as exc:
            for i in pending:
                store.finish_operation('generate:' + payload.job_id + ':' + i, success=False)
            if not isinstance(exc, Exception):
                raise
            raise HTTPException(502,'provider_failed_no_retry') from None
        finally:
            store.release()
    def tryon_inputs(payload):
        return {'person_image': payload.person_image, 'clothing_image': payload.clothing_image,
                'request_id': payload.request_id}

    @app.post('/api/tryon')
    def tryon(payload: TryOnRequest, request: Request, authorization: str | None = Header(None)):
        who = owner(authorization, request, paid=True)
        if not s.enabled or provider is None:
            raise HTTPException(503, 'inference_disabled')
        person = normalize(payload.person_image, s, upload=True)
        clothing = normalize(payload.clothing_image, s, preserve_alpha=True, upload=True)
        credit = credit_preflight('tryon', 40000)
        jid = 'tryon-' + secrets.token_urlsafe(24)
        operation = 'tryon:' + jid
        with store.tx() as db:
            consume_quote(db, payload, request, who, 'tryon', tryon_inputs(payload), 40000, credit)
            if db.execute('SELECT 1 FROM jobs WHERE owner=? AND request_id=?',
                          (who, 'tryon:' + payload.request_id)).fetchone():
                raise HTTPException(409, 'request_already_claimed')
            store.capacity(db, 2048)
            store.reserve(db, 40000, owner=who, enforce_budget=False)
            store.record_operation(db, operation, 40000, who)
            db.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?)',
                (jid, who, 'tryon:' + payload.request_id, quote_digest('tryon', tryon_inputs(payload)),
                 'claimed', None, None, time.time() + s.session_ttl_seconds))
        try:
            rid = provider.tryon_submit(person, clothing,
                before_submit=lambda: before_paid_submit(operation, 'tryon', 40000))
            with store.tx() as db:
                db.execute('UPDATE jobs SET state=?,result=? WHERE id=?',
                           ('pending', json.dumps({'request_id': rid}), jid))
            return {'job_id': jid, 'state': 'pending'}
        except Exception:
            store.finish_operation(operation, success=False)
            store.release()
            raise HTTPException(502, 'provider_failed_no_retry') from None

    @app.post('/api/tryon/pending')
    def pending_tryon(request: Request, authorization: str | None = Header(None)):
        who = owner(authorization, request, paid=True)
        with store.tx() as db:
            rows = db.execute(
                "SELECT id FROM jobs WHERE owner=? AND request_id LIKE 'tryon:%' "
                "AND state='pending' AND result IS NOT NULL AND expires>? LIMIT 2",
                (who, time.time()),
            ).fetchall()
        if len(rows) != 1:
            raise HTTPException(404, 'pending_tryon_not_found')
        return {'job_id': rows[0]['id']}

    @app.post('/api/tryon/status')
    def tryon_status(payload: TryOnStatus, request: Request, authorization: str | None = Header(None)):
        who = owner(authorization, request, paid=True)
        if not s.enabled or provider is None:
            raise HTTPException(503, 'inference_disabled')
        with store.tx() as db:
            row = db.execute('SELECT * FROM jobs WHERE id=? AND owner=?', (payload.job_id, who)).fetchone()
            if not row or not row['request_id'].startswith('tryon:') or row['expires'] <= time.time():
                raise HTTPException(404, 'job_not_found')
            if row['state'] == 'done':
                return json.loads(row['result'])
            if row['state'] == 'failed':
                return {'job_id': payload.job_id, 'state': 'failed'}
            if row['state'] != 'pending':
                raise HTTPException(409, 'request_ambiguous_no_retry')
        try:
            url = provider.tryon_poll(json.loads(row['result'])['request_id'])
        except Exception as exc:
            from virtual_tryon import TryOnError
            if isinstance(exc, TryOnError) and str(exc) == 'generation_failed':
                with store.tx() as db:
                    changed = db.execute("UPDATE jobs SET state='failed' WHERE id=? AND state='pending'", (payload.job_id,)).rowcount
                    if changed:
                        db.execute('UPDATE guard SET busy=0')
                return {'job_id': payload.job_id, 'state': 'failed'}
            # Keep resumable state: a transient GET failure never creates a new paid job.
            raise HTTPException(502, 'poll_failed_resume_same_job') from None
        if url is None:
            return {'job_id': payload.job_id, 'state': 'pending'}
        from virtual_tryon import safe_result_url
        if not safe_result_url(url):
            raise HTTPException(502, 'invalid_result')
        result = {'job_id': payload.job_id, 'state': 'done', 'image': url}
        with store.tx() as db:
            changed = db.execute("UPDATE jobs SET state=?,result=? WHERE id=? AND state='pending'",
                       ('done', json.dumps(result), payload.job_id)).rowcount
            if changed:
                table = store._operation_table(db, 'tryon:' + payload.job_id)
                db.execute(f"UPDATE {table} SET state='spent' WHERE id=? AND state='submitted'", ('tryon:' + payload.job_id,))
                db.execute('UPDATE guard SET busy=0')
        return result
    return app

def create_app_from_env():
    """Construct locally; configuration is not permission to submit inference."""
    settings = Settings.from_env()
    provider = None
    if settings.enabled and settings.github_owner_id:
        from providers import RealProviders
        provider = RealProviders.from_env()
    return create_app(settings, provider)


app = create_app_from_env()