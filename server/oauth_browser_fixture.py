"""LOCAL TEST FIXTURE ONLY: isolated HTTPS sites, no real OAuth/AI requests."""
import os
import base64
import hashlib
import secrets
from pathlib import Path
from urllib.parse import parse_qs, urlencode
from html import escape
import httpx
import app as api

root = Path(os.environ['OAUTH_FIXTURE_DIR'])
codes = {}

def transport(request):
    print('FIXTURE_PROVIDER_EXCHANGE', request.url.host, flush=True)
    if request.url.host == 'github.com':
        body = parse_qs(request.content.decode())
        challenge = codes.pop(body.get('code', [''])[0], None)
        verifier = body.get('code_verifier', [''])[0]
        actual = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b'=').decode()
        if not challenge or not secrets.compare_digest(actual, challenge):
            return httpx.Response(400, json={'error': 'invalid_grant'})
        return httpx.Response(200, json={'access_token': 'offline-fixture-token'})
    return httpx.Response(200, json={'id': 12345, 'login': 'yasinaday'})

api.oauth_http_client = lambda: httpx.Client(transport=httpx.MockTransport(transport))
app = api.create_app(dict(enabled=False, db_path=str(root/'fixture.db'),
    storage_dir=str(root/'images'), github_client_id='fixture-client',
    github_client_secret='fixture-secret', github_owner_id='12345',
    github_owner_login='yasinaday',
    github_redirect_uri='https://localhost:19443/api/auth/github/callback',
    github_return_url='https://yasinaday.github.io:19443/stylemuse-ai/',
    origin='https://yasinaday.github.io:19443'))

@app.middleware('http')
async def local_browser_sites(request, call_next):
    from starlette.responses import HTMLResponse
    if request.url.hostname == 'yasinaday.github.io':
        html = (Path(__file__).parent.parent/'index.html').read_text().replace(
            "const STYLEMUSE_API='https://stylemuse-api.129.121.148.187.sslip.io'",
            "const STYLEMUSE_API='https://localhost:19443'")
        return HTMLResponse(html)
    if request.url.hostname == 'github.com':
        code = secrets.token_urlsafe(32)
        codes[code] = request.query_params.get('code_challenge', '')
        callback = 'https://localhost:19443/api/auth/github/callback?' + urlencode({
            'state': request.query_params.get('state', ''), 'code': code})
        return HTMLResponse('<h1>Offline owner consent fixture</h1><a id="consent" href="' + escape(callback, quote=True) + '">Approve fixture owner</a>')
    response = await call_next(request)
    location = response.headers.get('location', '')
    if location.startswith('https://github.com/'):
        response.headers['location'] = location.replace('https://github.com/', 'https://github.com:19443/', 1)
    return response
