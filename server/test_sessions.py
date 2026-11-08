"""Offline session security regressions; never constructs a real provider."""
import pytest
from fastapi.testclient import TestClient
import app as api

ORIGIN = 'https://yasinaday.github.io'

@pytest.fixture
def client(tmp_path):
    return TestClient(api.create_app(dict(access_token='private-test-token',
        db_path=str(tmp_path/'state.sqlite'), storage_dir=str(tmp_path/'images'))),
        base_url='https://testserver')

def bootstrap(client):
    return client.post('/api/session', headers={'Origin': ORIGIN})

def test_bootstrap_cookie_and_disabled_health(client):
    response = bootstrap(client)
    assert response.status_code == 200
    assert response.json() == {'status': 'ok', 'enabled': False}
    cookie = response.headers['set-cookie'].lower()
    assert 'httponly' in cookie and 'secure' in cookie and 'samesite=none' in cookie
    assert 'path=/' in cookie and 'domain=' not in cookie
    assert 'private-test-token' not in cookie
    assert client.post('/api/health', headers={'Origin': ORIGIN}).status_code == 200

@pytest.mark.parametrize('origin', [None, 'null', ORIGIN + '.evil', ORIGIN + '/'])
def test_bootstrap_rejects_nonexact_origins(client, origin):
    response = client.post('/api/session', headers={} if origin is None else {'Origin': origin})
    assert response.status_code == 403
    assert 'set-cookie' not in response.headers

@pytest.mark.parametrize('path,payload', [('/api/health', None),
    ('/api/detect', {'image': 'invalid', 'request_id': 'r'}),
    ('/api/generate', {'job_id': 'j', 'item_ids': ['i']})])
@pytest.mark.parametrize('origin', [None, 'https://evil.invalid'])
def test_cookie_posts_require_origin(client, path, payload, origin):
    bootstrap(client)
    response = client.post(path, json=payload, headers={} if origin is None else {'Origin': origin})
    assert response.status_code == 403

def test_anonymous_cannot_spend_even_when_enabled(tmp_path):
    class NeverProvider:
        def detect(self, *args):
            pytest.fail('Inference must not be invoked')
        generate = detect
    c = TestClient(api.create_app(dict(enabled=True, lifetime_budget_usd=10,
        db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images')), NeverProvider()),
        base_url='https://testserver')
    bootstrap(c)
    for path, payload in [('/api/detect', {'image': 'invalid', 'request_id': 'r',
                'confirmed': True, 'max_total_usd': 10}),
            ('/api/generate', {'job_id': 'j', 'item_ids': ['i'],
                'confirmed': True, 'max_total_usd': 10})]:
        response = c.post(path, json=payload, headers={'Origin': ORIGIN})
        assert response.status_code == 403
        assert response.json() == {'error': 'paid_inference_not_authorized'}
    assert c.post('/api/health', headers={'Origin': ORIGIN}).json()['reserved_usd'] == 0

def test_public_health_is_redacted_bearer_post_retains_costs(client):
    for headers in ({}, {'Authorization': 'Bearer private-test-token'}):
        assert client.get('/api/health', headers=headers).json() == {'status': 'ok', 'enabled': False}
    assert client.post('/api/health').status_code == 401
    response = client.post('/api/health', headers={'Authorization': 'Bearer private-test-token'})
    assert response.status_code == 200
    assert response.json()['reserved_usd'] == 0

def test_credentialed_cors_is_exact(client):
    response = bootstrap(client)
    assert response.headers['access-control-allow-origin'] == ORIGIN
    assert response.headers['access-control-allow-credentials'] == 'true'
    bad = client.post('/api/session', headers={'Origin': 'https://evil.invalid'})
    assert 'access-control-allow-origin' not in bad.headers

def test_partitioned_cookie_emitted_on_older_python(client, monkeypatch):
    original = api.JSONResponse.set_cookie
    def older(self, *args, **kwargs):
        if kwargs.pop('partitioned', False):
            raise ValueError('Partitioned cookies are only supported in Python 3.14 and later.')
        return original(self, *args, **kwargs)
    monkeypatch.setattr(api.JSONResponse, 'set_cookie', older)
    assert '; partitioned' in bootstrap(client).headers['set-cookie'].lower()

def test_sessions_are_bounded_expire_and_bootstrap_reuses_valid_session(tmp_path, monkeypatch):
    now = [1000.0]
    monkeypatch.setattr(api.time, 'monotonic', lambda: now[0])
    assert hasattr(api.Settings, 'max_sessions'), 'Session capacity must be configurable and bounded'
    application = api.create_app(dict(max_sessions=2, session_ttl_seconds=10,
        db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images')))
    a, b, c = [TestClient(application, base_url='https://testserver') for _ in range(3)]
    first = bootstrap(a)
    assert first.status_code == 200
    token = a.cookies.get('__Host-stylemuse_session')
    assert len(token) >= 43
    assert bootstrap(a).status_code == 200
    assert a.cookies.get('__Host-stylemuse_session') == token
    assert bootstrap(b).status_code == 200
    assert b.cookies.get('__Host-stylemuse_session') != token
    assert bootstrap(c).status_code == 429
    now[0] += 10
    assert a.post('/api/health', headers={'Origin': ORIGIN}).status_code == 401
    assert bootstrap(c).status_code == 200
    assert a.post('/api/health', headers={'Origin': ORIGIN}).status_code == 401

def test_forged_cookie_and_restart_are_not_sessions(client, tmp_path):
    client.cookies.set('__Host-stylemuse_session', 'invented')
    assert client.post('/api/health', headers={'Origin': ORIGIN}).status_code == 401
    client.cookies.clear()
    bootstrap(client)
    token = client.cookies.get('__Host-stylemuse_session')
    restarted = TestClient(api.create_app(dict(db_path=str(tmp_path/'db'),
        storage_dir=str(tmp_path/'images'))), base_url='https://testserver')
    restarted.cookies.set('__Host-stylemuse_session', token)
    assert restarted.post('/api/health', headers={'Origin': ORIGIN}).status_code == 401

@pytest.mark.parametrize('settings', [{'origin': '*'}, {'origin': 'null'},
    {'origin': 'https://example.com/path'}, {'max_sessions': 0},
    {'session_ttl_seconds': 0}, {'session_ttl_seconds': float('inf')}])
def test_invalid_session_configuration_fails_closed(tmp_path, settings):
    with pytest.raises(ValueError):
        api.create_app(dict(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'), **settings))

def test_owner_ids_are_isolated_and_not_cookie_tokens(client):
    import inspect
    endpoint = next(route.endpoint for route in client.app.routes
                    if route.path == '/api/health' and 'POST' in route.methods)
    owner = inspect.getclosurevars(endpoint).nonlocals['owner']
    owners, tokens = [], []
    for _ in range(2):
        client.cookies.clear()
        bootstrap(client)
        token = client.cookies.get('__Host-stylemuse_session')
        tokens.append(token)
        request = api.Request({'type': 'http', 'method': 'POST', 'path': '/api/health',
            'headers': [(b'origin', ORIGIN.encode()),
                (b'cookie', ('__Host-stylemuse_session=' + token).encode())],
            'scheme': 'https', 'server': ('testserver', 443), 'query_string': b''})
        owners.append(owner(None, request))
    assert len(set(owners + tokens)) == 4
    assert all(len(who) >= 43 for who in owners)

def test_mounted_app_cannot_turn_session_into_paid_capability(tmp_path):
    application = api.FastAPI()
    application.mount('/mounted', api.create_app(dict(enabled=True,
        db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images')), object()))
    c = TestClient(application, base_url='https://testserver')
    assert c.post('/mounted/api/session', headers={'Origin': ORIGIN}).status_code == 200
    response = c.post('/mounted/api/detect', headers={'Origin': ORIGIN},
        json={'image': 'invalid', 'request_id': 'r', 'confirmed': True, 'max_total_usd': 1})
    assert response.status_code == 403
    assert response.json() == {'error': 'paid_inference_not_authorized'}
