import base64
import os
import secrets
import time
from collections import defaultdict, deque
from io import BytesIO

import httpx
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from PIL import Image, UnidentifiedImageError

REPLICATE_TOKEN = os.getenv("REPLICATE_API_TOKEN", "")
ACCESS_TOKEN = os.getenv("STYLEMUSE_ACCESS_TOKEN", "")
MODEL = os.getenv("REPLICATE_MODEL", "")
ORIGIN = os.getenv("STYLEMUSE_ORIGIN", "https://yasinaday.github.io")
MAX_BYTES = 6 * 1024 * 1024
MAX_CALLS = int(os.getenv("STYLEMUSE_HOURLY_LIMIT", "15"))
requests_by_client = defaultdict(deque)

app = FastAPI(title="StyleMuse private image analysis API", docs_url=None, redoc_url=None)
app.add_middleware(CORSMiddleware, allow_origins=[ORIGIN], allow_methods=["POST", "GET"], allow_headers=["Authorization", "Content-Type"])

class AnalyzeRequest(BaseModel):
    image: str = Field(min_length=50, max_length=9_000_000)
    prompt: str = Field(default="shirt, trousers, dress, shoes, handbag", max_length=300)

def authenticate(authorization):
    if not ACCESS_TOKEN or not REPLICATE_TOKEN or not MODEL:
        raise HTTPException(503, "Sunucu henüz yapılandırılmadı")
    if not authorization or not authorization.startswith("Bearer ") or not secrets.compare_digest(authorization[7:], ACCESS_TOKEN):
        raise HTTPException(401, "Yetkisiz istek")

def validate_image(data_uri):
    if not (data_uri.startswith("data:image/jpeg;base64,") or data_uri.startswith("data:image/png;base64,")):
        raise HTTPException(422, "Yalnızca JPEG ve PNG kabul edilir")
    try:
        raw = base64.b64decode(data_uri.split(",", 1)[1], validate=True)
        if len(raw) > MAX_BYTES:
            raise HTTPException(413, "Fotoğraf 6 MB sınırını aşıyor")
        with Image.open(BytesIO(raw)) as im:
            if im.format not in ("JPEG", "PNG") or im.width * im.height > 16_000_000:
                raise HTTPException(422, "Desteklenmeyen görüntü")
            im.verify()
    except (ValueError, UnidentifiedImageError, OSError):
        raise HTTPException(422, "Geçersiz fotoğraf")
    return data_uri

@app.get("/health")
def health():
    return {"status": "ok", "configured": bool(REPLICATE_TOKEN and ACCESS_TOKEN and MODEL)}

@app.post("/v1/analyze")
async def analyze(payload: AnalyzeRequest, request: Request, authorization: str | None = Header(default=None)):
    authenticate(authorization)
    image = validate_image(payload.image)
    client_id = request.client.host if request.client else "unknown"
    bucket = requests_by_client[client_id]
    now = time.monotonic()
    while bucket and now - bucket[0] > 3600:
        bucket.popleft()
    if len(bucket) >= MAX_CALLS:
        raise HTTPException(429, "Saatlik test limiti doldu")
    bucket.append(now)
    owner, sep, name = MODEL.partition("/")
    if not sep or not owner or not name:
        raise HTTPException(503, "Model tanımı geçersiz")
    # Input schema differs by Replicate model; verify model contract before enabling paid calls.
    async with httpx.AsyncClient(timeout=45) as client_http:
        try:
            result = await client_http.post(
                f"https://api.replicate.com/v1/models/{owner}/{name}/predictions",
                headers={"Authorization": f"Bearer {REPLICATE_TOKEN}", "Content-Type": "application/json", "Prefer": "wait=25"},
                json={"input": {"image": image, "prompt": payload.prompt}},
            )
            result.raise_for_status()
        except httpx.HTTPStatusError as exc:
            raise HTTPException(502, f"Model isteği başarısız (HTTP {exc.response.status_code})")
        except httpx.HTTPError:
            raise HTTPException(502, "Yapay zekâ servisine ulaşılamadı")
    data = result.json()
    return {"id": data.get("id"), "status": data.get("status"), "output": data.get("output"), "message": "Model çıktısı doğrulanmadan otomatik dolaba kaydedilmez."}
