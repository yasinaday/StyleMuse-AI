"""Offline OAuth transport fixtures only: no real provider/network calls."""
from urllib.parse import urlsplit, parse_qs
import pytest
from fastapi.testclient import TestClient
import app as api

ORIGIN = 'https://yasinaday.github.io'
HEADERS = {'Origin': ORIGIN}

def make(tmp_path, **changes):
    settings = dict(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'))
    settings.update(changes)
    return TestClient(api.create_app(settings), base_url='https://testserver')

CONFIG = dict(github_client_id='test-client', github_client_secret='server-secret',
    github_owner_id='12345', github_owner_login='yasinaday',
    github_redirect_uri='https://testserver/api/auth/github/callback',
    github_return_url=ORIGIN + '/stylemuse-ai/')

def configured(tmp_path, **changes):
    return make(tmp_path, **(CONFIG | changes))

def start_authorization(c):
    start = c.post('/api/auth/github/start', headers=HEADERS)
    assert start.status_code == 200
    launch = c.get(start.json()['launch_url'], follow_redirects=False)
    handoff = parse_qs(urlsplit(launch.headers['location']).fragment)['oauth_handoff'][0]
    verified = c.post('/api/auth/github/handoff', headers=HEADERS, json={'handoff': handoff})
    authorize = c.get(verified.json()['authorization_url'], follow_redirects=False)
    return authorize.headers['location']


def test_oauth_owner_login_bound_to_original_session_with_pkce(tmp_path, monkeypatch):
    assert hasattr(api.Settings, 'github_owner_id'), 'OAuth owner configuration is missing'
    import httpx
    calls = []
    def transport(request):
        calls.append(request)
        if request.url.host == 'github.com':
            return httpx.Response(200, json={'access_token': 'github-server-token', 'token_type': 'bearer'})
        assert request.url == 'https://api.github.com/user'
        assert request.headers['Authorization'] == 'Bearer github-server-token'
        return httpx.Response(200, json={'id': 12345, 'login': 'yasinaday'})
    real_client = httpx.Client
    monkeypatch.setattr(api, 'oauth_http_client', lambda: real_client(transport=httpx.MockTransport(transport)))
    c = configured(tmp_path)
    c.post('/api/session', headers=HEADERS)
    query = parse_qs(urlsplit(start_authorization(c)).query)
    assert query['redirect_uri'] == [CONFIG['github_redirect_uri']]
    assert query['code_challenge_method'] == ['S256']
    assert len(query['code_challenge'][0]) == 43
    # Callback has the independent unpartitioned proof, not the CHIPS cookie.
    callback_client = TestClient(c.app, base_url='https://testserver')
    callback_client.cookies.set('__Host-stylemuse_oauth_browser', c.cookies.get('__Host-stylemuse_oauth_browser'))
    callback = callback_client.get('/api/auth/github/callback', params={'state': query['state'][0], 'code': 'test-code'}, follow_redirects=False)
    assert callback.status_code == 303
    assert callback.headers['location'] == CONFIG['github_return_url']
    assert 'github-server-token' not in callback.text + str(callback.headers)
    exchange = parse_qs(calls[0].content.decode())
    import base64, hashlib
    assert base64.urlsafe_b64encode(hashlib.sha256(exchange['code_verifier'][0].encode()).digest()).rstrip(b'=').decode() == query['code_challenge'][0]
    assert exchange['redirect_uri'] == [CONFIG['github_redirect_uri']]
    status = c.post('/api/session', headers=HEADERS)
    assert status.json()['authenticated'] is True
    assert status.json()['identity'] == {'provider': 'github', 'id': '12345', 'login': 'yasinaday'}
    assert status.headers['cache-control'] == 'no-store'

def test_owner_config_disables_private_bearer_bypass(tmp_path):
    c = configured(tmp_path, access_token='private', enabled=True, lifetime_budget_usd=.5)
    for path, payload in [('/api/detect', {'image': 'invalid', 'request_id': 'x'}),
                          ('/api/generate', {'job_id': 'x', 'item_ids': ['x']})]:
        assert c.post(path, json=payload, headers={'Authorization': 'Bearer private'}).status_code == 401
    c.post('/api/session', headers=HEADERS)
    assert c.post('/api/detect', json={'image':'invalid','request_id':'x'}, headers=HEADERS).status_code == 403

def test_enabled_owner_with_incomplete_oauth_rejected(tmp_path):
    with pytest.raises(ValueError, match='OAuth'):
        make(tmp_path, enabled=True, github_owner_id='12345', github_owner_login='yasinaday')

def login(c, monkeypatch, user=None):
    import httpx
    user = user or {'id': 12345, 'login': 'yasinaday'}
    def transport(request):
        if request.url.host == 'github.com':
            return httpx.Response(200, json={'access_token':'fixture-token'})
        return httpx.Response(200, json=user)
    real_client = httpx.Client
    monkeypatch.setattr(api, 'oauth_http_client', lambda: real_client(transport=httpx.MockTransport(transport)))
    c.post('/api/session', headers=HEADERS)
    state = parse_qs(urlsplit(start_authorization(c)).query)['state'][0]
    callback_client = c
    return callback_client.get('/api/auth/github/callback', params={'state':state,'code':'fixture-code'}, follow_redirects=False)

def test_oauth_owner_gets_paid_admission_and_health_identity(tmp_path, monkeypatch):
    from test_api import Provider, image
    p = Provider()
    c = TestClient(api.create_app(dict(CONFIG, enabled=True, lifetime_budget_usd=.5,
        db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images')), p), base_url='https://testserver')
    assert login(c, monkeypatch).status_code == 303
    health = c.post('/api/health', headers=HEADERS).json()
    assert health['authenticated'] is True
    assert health['identity']['id'] == '12345'
    r = c.post('/api/detect', headers=HEADERS, json=dict(image=image(), request_id='owner', confirmed=True, max_total_usd=.05))
    assert r.status_code == 200
    assert p.detect_calls == 1

def test_logout_revokes_session_and_pending_states(tmp_path, monkeypatch):
    c = configured(tmp_path)
    assert login(c, monkeypatch).status_code == 303
    old_cookie = c.cookies.get('__Host-stylemuse_session')
    state = parse_qs(urlsplit(start_authorization(c)).query)['state'][0]
    assert c.post('/api/auth/logout').status_code == 403
    r = c.post('/api/auth/logout', headers=HEADERS)
    assert r.status_code == 200
    assert r.json() == {'status':'ok','authenticated':False,'identity':None}
    assert 'max-age=0' in r.headers['set-cookie'].lower()
    assert '; partitioned' in r.headers['set-cookie'].lower()
    c.cookies.set('__Host-stylemuse_session', old_cookie)
    assert c.post('/api/health', headers=HEADERS).status_code == 401
    assert c.get('/api/auth/github/callback', params={'state':state,'code':'x'}).status_code == 403

def test_oauth_paid_routes_use_durable_owner_cap(tmp_path, monkeypatch):
    from test_api import Provider, image
    p = Provider()
    c = TestClient(api.create_app(dict(CONFIG, enabled=True, lifetime_budget_usd=.5,
        owner_lifetime_budget_usd=.05, db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images')), p), base_url='https://testserver')
    assert login(c, monkeypatch).status_code == 303
    payload = dict(image=image(), request_id='first', confirmed=True, max_total_usd=.05)
    first = c.post('/api/detect', headers=HEADERS, json=payload)
    assert first.status_code == 200
    job = first.json()
    blocked = c.post('/api/generate', headers=HEADERS, json=dict(job_id=job['job_id'],
        item_ids=[job['items'][0]['id']], confirmed=True, max_total_usd=.1))
    assert blocked.status_code == 402
    assert blocked.json()['error'] == 'owner_budget_exceeded'
    payload['request_id'] = 'second'
    assert c.post('/api/detect', headers=HEADERS, json=payload).status_code == 402
    assert p.detect_calls == 1 and p.generate_calls == 0

@pytest.mark.parametrize('user', [{'id': 999, 'login':'yasinaday'},
    {'id':12345,'login':'attacker'}, {'id':'12345','login':'yasinaday'}])
def test_wrong_github_identity_never_authorizes(tmp_path, monkeypatch, user):
    c = configured(tmp_path)
    assert login(c, monkeypatch, user).status_code == 403
    assert c.post('/api/session', headers=HEADERS).json()['authenticated'] is False
    assert c.post('/api/detect', headers=HEADERS, json={'image':'invalid','request_id':'x'}).status_code == 403


def test_state_expiration_replay_and_new_start_invalidation(tmp_path, monkeypatch):
    now = [1000.0]
    monkeypatch.setattr(api.time, 'monotonic', lambda: now[0])
    c = configured(tmp_path, oauth_state_ttl_seconds=10)
    c.post('/api/session', headers=HEADERS)
    def start():
        return parse_qs(urlsplit(start_authorization(c)).query)['state'][0]
    expired = start()
    now[0] += 10
    assert c.get('/api/auth/github/callback', params={'state':expired,'code':'x'}).json() == {'error':'oauth_state_invalid'}
    old, new = start(), start()
    assert old != new
    assert c.get('/api/auth/github/callback', params={'state':old,'code':'x'}).status_code == 403
    # Provider denial consumes state; replay cannot exchange code.
    assert c.get('/api/auth/github/callback', params={'state':new,'error':'access_denied'}).json() == {'error':'oauth_denied'}
    assert c.get('/api/auth/github/callback', params={'state':new,'code':'x'}).json() == {'error':'oauth_state_invalid'}
    assert c.get('/api/auth/github/callback', params={'state':'invented','code':'x'}).status_code == 403


def test_success_state_is_single_use_and_does_not_authorize_other_session(tmp_path, monkeypatch):
    c = configured(tmp_path)
    # Capture the exact successfully consumed state through the URL.
    original_get = TestClient.get
    used = []
    def record(self, url, **kw):
        if url == '/api/auth/github/callback':
            used.append(kw['params']['state'])
        return original_get(self, url, **kw)
    monkeypatch.setattr(TestClient, 'get', record)
    assert login(c, monkeypatch).status_code == 303
    other = TestClient(c.app, base_url='https://testserver')
    other.post('/api/session', headers=HEADERS)
    assert other.post('/api/session', headers=HEADERS).json()['authenticated'] is False
    assert other.get('/api/auth/github/callback', params={'state':used[0],'code':'x'}).status_code == 403
    assert other.post('/api/session', headers=HEADERS).json()['authenticated'] is False


@pytest.mark.parametrize('origin', [None, 'null', ORIGIN + '.evil', ORIGIN + '/'])
def test_login_start_requires_exact_origin(tmp_path, origin):
    c = configured(tmp_path)
    c.post('/api/session', headers=HEADERS)
    assert c.post('/api/auth/github/start', headers={} if origin is None else {'Origin':origin}).status_code == 403


def test_login_start_requires_existing_session(tmp_path):
    c = configured(tmp_path)
    assert c.post('/api/auth/github/start', headers=HEADERS).status_code == 401
    assert c.get('/api/auth/github/start').status_code == 405


@pytest.mark.parametrize('changes', [{'github_client_secret':''}, {'github_owner_id':''},
    {'github_owner_id':'00012345'}, {'github_owner_id':'yasinaday'},
    {'github_redirect_uri':'http://testserver/api/auth/github/callback'},
    {'github_redirect_uri':'https://testserver/api/auth/github/callback?next=evil'},
    {'github_return_url':'https://evil.invalid/'}, {'github_return_url':ORIGIN+'.evil/'}])
def test_incomplete_or_unsafe_oauth_configuration_is_closed(tmp_path, changes):
    c = configured(tmp_path, **changes)
    c.post('/api/session', headers=HEADERS)
    r = c.post('/api/auth/github/start', headers=HEADERS)
    assert r.status_code == 503
    assert r.headers['cache-control'] == 'no-store'


def test_logout_does_not_restore_auth_on_rebootstrap(tmp_path, monkeypatch):
    c = configured(tmp_path)
    assert login(c, monkeypatch).status_code == 303
    c.post('/api/auth/logout', headers=HEADERS)
    assert c.post('/api/session', headers=HEADERS).json()['authenticated'] is False


def test_oauth_provider_error_is_redacted_and_state_consumed(tmp_path, monkeypatch):
    import httpx
    c = configured(tmp_path)
    c.post('/api/session', headers=HEADERS)
    state = parse_qs(urlsplit(start_authorization(c)).query)['state'][0]
    real_client = httpx.Client
    def fail(request):
        raise RuntimeError('SECRET_ACCESS_TOKEN')
    monkeypatch.setattr(api, 'oauth_http_client', lambda: real_client(transport=httpx.MockTransport(fail)))
    r = c.get('/api/auth/github/callback', params={'state':state,'code':'x'})
    assert r.status_code == 502 and r.json() == {'error':'oauth_provider_failed'}
    assert r.headers['cache-control'] == 'no-store'
    assert c.get('/api/auth/github/callback', params={'state':state,'code':'x'}).status_code == 403


def test_expired_session_prunes_authorization_memory(tmp_path, monkeypatch):
    import inspect
    now = [1000.0]
    monkeypatch.setattr(api.time, 'monotonic', lambda: now[0])
    c = configured(tmp_path, session_ttl_seconds=10)
    assert login(c, monkeypatch).status_code == 303
    endpoint = next(r.endpoint for r in c.app.routes if r.path == '/api/auth/github/callback')
    authorized = inspect.getclosurevars(endpoint).nonlocals['authorized']
    assert len(authorized) == 1
    now[0] += 10
    assert c.post('/api/health', headers=HEADERS).status_code == 401
    assert c.post('/api/session', headers=HEADERS).json()['authenticated'] is False
    assert len(authorized) == 0


def test_env_owner_mode_constructs_provider_without_private_bearer(tmp_path, monkeypatch):
    import providers
    for key in list(api.os.environ):
        if key.startswith('STYLEMUSE_'):
            monkeypatch.delenv(key)
    config = dict(CONFIG, enabled='true', lifetime_budget_usd='.5',
        db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'))
    for key, value in config.items():
        monkeypatch.setenv('STYLEMUSE_' + key.upper(), str(value))
    called = []
    monkeypatch.setattr(providers.RealProviders, 'from_env', lambda: called.append(True) or object())
    api.create_app_from_env()
    assert called == [True]


@pytest.mark.parametrize('body', [[], None, 'invalid'])
def test_malformed_github_user_fails_closed_redacted(tmp_path, monkeypatch, body):
    import httpx
    c = configured(tmp_path)
    c.post('/api/session', headers=HEADERS)
    state = parse_qs(urlsplit(start_authorization(c)).query)['state'][0]
    real_client = httpx.Client
    def transport(request):
        return httpx.Response(200, json={'access_token':'fixture-token'} if request.url.host == 'github.com' else body)
    monkeypatch.setattr(api, 'oauth_http_client', lambda: real_client(transport=httpx.MockTransport(transport)))
    callback = c
    r = callback.get('/api/auth/github/callback', params={'state':state,'code':'x'})
    assert r.status_code == 502
    assert r.json() == {'error':'oauth_provider_failed'}
    assert r.headers['cache-control'] == 'no-store'


def test_owner_rate_is_shared_across_reauthentication_and_restart(tmp_path, monkeypatch):
    from test_api import Provider, image
    p = Provider()
    settings = dict(CONFIG, enabled=True, lifetime_budget_usd=.5, owner_rate_limit=1,
        db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'))
    def client():
        return TestClient(api.create_app(settings, p), base_url='https://testserver')
    first = client()
    assert login(first, monkeypatch).status_code == 303
    payload = dict(image=image(), request_id='first', confirmed=True, max_total_usd=.05)
    assert first.post('/api/detect', headers=HEADERS, json=payload).status_code == 200
    first.post('/api/auth/logout', headers=HEADERS)
    second = client()
    assert login(second, monkeypatch).status_code == 303
    payload['request_id'] = 'second'
    r = second.post('/api/detect', headers=HEADERS, json=payload)
    assert r.status_code == 429 and r.json()['error'] == 'owner_rate_limited'
    assert second.post('/api/health', headers=HEADERS).json()['reserved_usd'] == .05
    assert p.detect_calls == 1


def test_oauth_missing_configuration_fails_closed(tmp_path):
    c = make(tmp_path)
    c.post('/api/session', headers=HEADERS)
    r = c.post('/api/auth/github/start', headers=HEADERS)
    assert r.status_code == 503
    assert r.json() == {'error': 'oauth_not_configured'}
