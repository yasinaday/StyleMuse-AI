"""Offline two-browser attack regressions; provider is a fixture, never network."""
from urllib.parse import urlsplit, parse_qs
from fastapi.testclient import TestClient
from test_oauth import configured, HEADERS, start_authorization
import app as api
import httpx


def fixture_provider(monkeypatch):
    calls = []
    def transport(request):
        calls.append(request)
        return httpx.Response(200, json={'access_token': 'fixture'} if request.url.host == 'github.com' else {'id': 12345, 'login': 'yasinaday'})
    monkeypatch.setattr(api, 'oauth_http_client', lambda: httpx.Client(transport=httpx.MockTransport(transport)))
    return calls


def test_forwarded_authorization_url_never_authorizes_attacker(tmp_path, monkeypatch):
    calls = fixture_provider(monkeypatch)
    attacker = configured(tmp_path)
    attacker.post('/api/session', headers=HEADERS)
    start = attacker.post('/api/auth/github/start', headers=HEADERS).json()
    # Follow the complete legitimate initiation in the attacker's browser when
    # the secure bridge exists, then forward only the provider URL to victim.
    url = start.get('launch_url', start.get('authorization_url'))
    if 'launch_url' in start:
        launch = attacker.get(url, follow_redirects=False)
        handoff = parse_qs(urlsplit(launch.headers['location']).fragment)['oauth_handoff'][0]
        verify = attacker.post('/api/auth/github/handoff', headers=HEADERS, json={'handoff': handoff})
        authorize = attacker.get(verify.json()['authorization_url'], follow_redirects=False)
        url = authorize.headers['location']
    state = parse_qs(urlsplit(url).query)['state'][0]
    victim = TestClient(attacker.app, base_url='https://testserver')
    response = victim.get('/api/auth/github/callback', params={'state': state, 'code': 'victim-owner-code'}, follow_redirects=False)
    assert response.status_code == 403, 'forwarded OAuth URL authorized the attacker session'
    assert calls == [], 'browser rejection must precede provider token exchange'
    assert attacker.post('/api/session', headers=HEADERS).json()['authenticated'] is False


def test_verified_pages_handoff_binds_top_level_browser_and_original_session(tmp_path, monkeypatch):
    calls = fixture_provider(monkeypatch)
    pages = configured(tmp_path)
    pages.post('/api/session', headers=HEADERS)
    start = pages.post('/api/auth/github/start', headers=HEADERS).json()
    assert 'launch_url' in start
    top = TestClient(pages.app, base_url='https://testserver')
    launch = top.get(start['launch_url'], follow_redirects=False)
    assert launch.status_code == 303
    cookie = launch.headers['set-cookie'].lower()
    assert '__host-stylemuse_oauth_browser=' in cookie
    assert 'secure' in cookie and 'httponly' in cookie and 'samesite=lax' in cookie
    assert 'partitioned' not in cookie and 'domain=' not in cookie
    handoff = parse_qs(urlsplit(launch.headers['location']).fragment)['oauth_handoff'][0]
    verified = pages.post('/api/auth/github/handoff', headers=HEADERS, json={'handoff': handoff})
    assert verified.status_code == 200
    authorize = top.get(verified.json()['authorization_url'], follow_redirects=False)
    assert authorize.status_code == 303
    state = parse_qs(urlsplit(authorize.headers['location']).query)['state'][0]
    response = top.get('/api/auth/github/callback', params={'state': state, 'code': 'owner'}, follow_redirects=False)
    assert response.status_code == 303
    assert len(calls) == 2
    assert pages.post('/api/session', headers=HEADERS).json()['authenticated'] is True


def test_wrong_browser_callback_cannot_consume_legitimate_attempt(tmp_path, monkeypatch):
    calls = fixture_provider(monkeypatch)
    owner = configured(tmp_path)
    owner.post('/api/session', headers=HEADERS)
    state = parse_qs(urlsplit(start_authorization(owner)).query)['state'][0]
    other = TestClient(owner.app, base_url='https://testserver')
    params = {'state': state, 'code': 'fixture'}
    for proof in ('', 'different-browser-proof'):
        other.cookies.set('__Host-stylemuse_oauth_browser', proof)
        assert other.get('/api/auth/github/callback', params=params).status_code == 403
    assert calls == []
    assert owner.get('/api/auth/github/callback', params=params, follow_redirects=False).status_code == 303
    assert owner.get('/api/auth/github/callback', params=params, follow_redirects=False).status_code == 403
    assert len(calls) == 2


def test_forwarded_launch_and_handoff_cannot_bind_other_session(tmp_path, monkeypatch):
    calls = fixture_provider(monkeypatch)
    attacker = configured(tmp_path)
    victim = TestClient(attacker.app, base_url='https://testserver')
    for client in (attacker, victim):
        client.post('/api/session', headers=HEADERS)
    launch_url = attacker.post('/api/auth/github/start', headers=HEADERS).json()['launch_url']
    launch = victim.get(launch_url, follow_redirects=False)
    handoff = parse_qs(urlsplit(launch.headers['location']).fragment)['oauth_handoff'][0]
    assert victim.post('/api/auth/github/handoff', headers=HEADERS, json={'handoff': handoff}).status_code == 403
    assert victim.get(launch_url, follow_redirects=False).status_code == 403
    assert calls == []
    for client in (attacker, victim):
        assert client.post('/api/session', headers=HEADERS).json()['authenticated'] is False


def test_authorize_requires_matching_browser_and_handoff_is_single_use(tmp_path, monkeypatch):
    calls = fixture_provider(monkeypatch)
    owner = configured(tmp_path)
    owner.post('/api/session', headers=HEADERS)
    launch_url = owner.post('/api/auth/github/start', headers=HEADERS).json()['launch_url']
    launch = owner.get(launch_url, follow_redirects=False)
    handoff = parse_qs(urlsplit(launch.headers['location']).fragment)['oauth_handoff'][0]
    payload = {'handoff': handoff}
    authorize_url = owner.post('/api/auth/github/handoff', headers=HEADERS, json=payload).json()['authorization_url']
    assert owner.post('/api/auth/github/handoff', headers=HEADERS, json=payload).status_code == 403
    other = TestClient(owner.app, base_url='https://testserver')
    assert other.get(authorize_url, follow_redirects=False).status_code == 403
    assert owner.get(authorize_url, follow_redirects=False).status_code == 303
    assert owner.get(authorize_url, follow_redirects=False).status_code == 403
    assert calls == []


def test_superseded_callback_cannot_authorize_after_provider_io(tmp_path, monkeypatch):
    owner = configured(tmp_path)
    owner.post('/api/session', headers=HEADERS)
    state = parse_qs(urlsplit(start_authorization(owner)).query)['state'][0]
    def transport(request):
        if request.url.host == 'github.com':
            assert owner.post('/api/auth/github/start', headers=HEADERS).status_code == 200
            return httpx.Response(200, json={'access_token': 'fixture'})
        return httpx.Response(200, json={'id': 12345, 'login': 'yasinaday'})
    monkeypatch.setattr(api, 'oauth_http_client', lambda: httpx.Client(transport=httpx.MockTransport(transport)))
    assert owner.get('/api/auth/github/callback', params={'state': state, 'code': 'fixture'}, follow_redirects=False).status_code == 403
    assert owner.post('/api/session', headers=HEADERS).json()['authenticated'] is False


def test_oauth_expiring_during_provider_io_cannot_authorize(tmp_path, monkeypatch):
    now = [1000.0]
    monkeypatch.setattr(api.time, 'monotonic', lambda: now[0])
    owner = configured(tmp_path, oauth_state_ttl_seconds=10)
    owner.post('/api/session', headers=HEADERS)
    state = parse_qs(urlsplit(start_authorization(owner)).query)['state'][0]
    def transport(request):
        now[0] = 1010.0
        return httpx.Response(200, json={'access_token': 'fixture'} if request.url.host == 'github.com' else {'id': 12345, 'login': 'yasinaday'})
    monkeypatch.setattr(api, 'oauth_http_client', lambda: httpx.Client(transport=httpx.MockTransport(transport)))
    assert owner.get('/api/auth/github/callback', params={'state': state, 'code': 'fixture'}, follow_redirects=False).status_code == 403
    assert owner.post('/api/session', headers=HEADERS).json()['authenticated'] is False

