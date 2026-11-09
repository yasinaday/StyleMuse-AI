import base64
from io import BytesIO
import pytest
from PIL import Image
from fastapi.testclient import TestClient
import app as api


def image():
    b = BytesIO()
    Image.new('RGB', (4, 4), 'red').save(b, 'PNG')
    return 'data:image/png;base64,' + base64.b64encode(b.getvalue()).decode()


class Provider:
    def __init__(self):
        self.detect_calls = 0
        self.generate_calls = 0
    def detect(self, raw):
        self.detect_calls += 1
        return [dict(category='shirt', preview=image(), prompt='shirt')]
    def generate(self, original, item):
        self.generate_calls += 1
        return image()


def setup(tmp_path, **kwargs):
    settings = dict(access_token='secret', db_path=str(tmp_path/'db.sqlite'), storage_dir=str(tmp_path/'images'), **kwargs)
    p = Provider()
    c = TestClient(api.create_app(settings, p))
    c.headers['Authorization'] = 'Bearer secret'
    return c, p, settings


def detect(c, **kwargs):
    return c.post('/api/detect', json=dict(image=image(), request_id='request-1', confirmed=True, max_total_usd=1, **kwargs))


def test_failure_reservation_never_retried_and_ceiling_cannot_increase(tmp_path):
    c,p,settings = setup(tmp_path,enabled=True,lifetime_budget_usd=.05)
    def fail(original):
        p.detect_calls += 1
        raise RuntimeError('SECRET remote error')
    p.detect = fail
    r = detect(c)
    assert r.status_code == 502 and 'SECRET' not in r.text
    assert detect(c).status_code == 409
    assert p.detect_calls == 1
    restarted = TestClient(api.create_app(dict(settings,lifetime_budget_usd=100),p))
    restarted.headers['Authorization']='Bearer secret'
    assert restarted.post('/api/health').json()['lifetime_budget_usd'] == .05
    assert restarted.post('/api/health').json()['reserved_usd'] == .05
    assert restarted.post('/api/detect',json=dict(image=image(),request_id='new',confirmed=True,max_total_usd=1)).status_code == 402


def test_busy_guard_blocks_concurrent_calls(tmp_path):
    import threading
    c,p,_ = setup(tmp_path,enabled=True,lifetime_budget_usd=1)
    entered,finish = threading.Event(),threading.Event()
    original = p.detect
    def blocking(raw):
        entered.set()
        assert finish.wait(5)
        return original(raw)
    p.detect = blocking
    responses = []
    thread = threading.Thread(target=lambda:responses.append(detect(c)))
    thread.start()
    assert entered.wait(5)
    try:
        assert c.post('/api/detect',json=dict(image=image(),request_id='parallel',confirmed=True,max_total_usd=1)).status_code == 409
    finally:
        finish.set()
        thread.join(5)
    assert responses[0].status_code == 200
    assert p.detect_calls == 1


def test_storage_admission_expiry_and_owner(tmp_path):
    c,p,settings = setup(tmp_path, enabled=True,lifetime_budget_usd=1,max_storage_bytes=1)
    assert detect(c).status_code == 507
    assert p.detect_calls == 0
    c,p,settings = setup(tmp_path/'owner',enabled=True,lifetime_budget_usd=1)
    job = detect(c).json()
    second = TestClient(api.create_app(dict(settings,access_token='other'),p))
    second.headers['Authorization']='Bearer other'
    assert second.post('/api/generate',json=dict(job_id=job['job_id'],item_ids=[job['items'][0]['id']],confirmed=True,max_total_usd=1)).status_code == 404


def test_safe_errors_body_bound_and_confirmation(tmp_path):
    c,p,_ = setup(tmp_path, enabled=True,lifetime_budget_usd=1,max_request_bytes=1000)
    r = c.post('/api/detect',json={'image':'PRIVATE','confirmed':True,'request_id':{}})
    assert r.status_code == 422
    assert 'PRIVATE' not in r.text
    assert 'input' not in r.text
    assert c.post('/api/detect',content=b'x'*1001).status_code == 413
    assert c.post('/api/detect',json=dict(image=image(),request_id='x',confirmed=False,max_total_usd=1)).status_code == 403
    assert p.detect_calls == 0


def test_generation_owned_unique_claim(tmp_path):
    c,p,_ = setup(tmp_path, enabled=True, lifetime_budget_usd=1)
    job = detect(c).json()
    data = dict(job_id=job['job_id'], item_ids=[job['items'][0]['id']], confirmed=True,max_total_usd=.1)
    bad = dict(data, item_ids=['foreign'])
    assert c.post('/api/generate',json=bad).status_code == 404
    r = c.post('/api/generate',json=data)
    assert r.status_code == 200
    assert r.json()['items'][0]['image'].startswith('data:image/png;base64,')
    assert c.post('/api/generate',json=data).json() == r.json()
    assert p.generate_calls == 1


def test_detection_idempotent_durable_budget(tmp_path):
    c, p, settings = setup(tmp_path, enabled=True, lifetime_budget_usd=.1)
    r = detect(c)
    assert r.status_code == 200
    assert r.json()['items'][0]['category'] == 'shirt'
    assert detect(c).json() == r.json()
    assert p.detect_calls == 1
    again = TestClient(api.create_app(settings, p))
    again.headers['Authorization'] = 'Bearer secret'
    assert detect(again).json() == r.json()
    assert again.post('/api/health').json()['reserved_usd'] == .05


def test_environment_constructor_is_inert_and_defaults_closed(tmp_path, monkeypatch):
    for name in list(__import__('os').environ):
        if name.startswith('STYLEMUSE_'):
            monkeypatch.delenv(name)
    monkeypatch.setenv('STYLEMUSE_ACCESS_TOKEN', 'local-test-token')
    monkeypatch.setenv('STYLEMUSE_DB_PATH', str(tmp_path/'env.sqlite'))
    monkeypatch.setenv('STYLEMUSE_STORAGE_DIR', str(tmp_path/'images'))
    monkeypatch.setenv('STYLEMUSE_ORIGIN', 'https://local.example')
    settings = api.Settings.from_env()
    assert settings.origin == 'https://local.example'
    client = TestClient(api.create_app_from_env())
    client.headers['Authorization'] = 'Bearer local-test-token'
    assert client.post('/api/health').json() == {'status': 'ok', 'enabled': False,
        'reserved_usd': 0, 'lifetime_budget_usd': 0,
        'spent_usd': 0, 'pending_usd': 0, 'remaining_usd': 0}
    assert detect(client).status_code == 503


def test_environment_explicit_configuration_wires_inert_provider(tmp_path, monkeypatch):
    import providers
    monkeypatch.setenv('STYLEMUSE_ACCESS_TOKEN', 'local-test-token')
    monkeypatch.setenv('STYLEMUSE_DB_PATH', str(tmp_path/'env.sqlite'))
    monkeypatch.setenv('STYLEMUSE_STORAGE_DIR', str(tmp_path/'images'))
    monkeypatch.setenv('STYLEMUSE_ENABLED', 'true')
    monkeypatch.setenv('STYLEMUSE_LIFETIME_BUDGET_USD', '0.25')
    monkeypatch.setenv('STYLEMUSE_MAX_PIXELS', '1048576')
    provider = Provider()
    monkeypatch.setattr(providers.RealProviders, 'from_env', lambda: provider)
    settings = api.Settings.from_env()
    assert settings.enabled is True
    assert settings.lifetime_budget_usd == .25
    assert settings.max_pixels == 1048576
    client = TestClient(api.create_app_from_env())
    assert provider.detect_calls == provider.generate_calls == 0
    client.headers['Authorization'] = 'Bearer local-test-token'
    assert detect(client).status_code == 200
    assert provider.detect_calls == 1


@pytest.mark.parametrize('name,value', [('ENABLED', 'yes'), ('LIFETIME_BUDGET_USD', 'nan'),
    ('DETECT_RESERVATION_USD', '0'), ('GENERATION_RESERVATION_USD', '-1'), ('MAX_PIXELS', '0')])
def test_environment_rejects_unsafe_configuration(monkeypatch, name, value):
    monkeypatch.setenv('STYLEMUSE_' + name, value)
    with pytest.raises(ValueError):
        api.Settings.from_env()


def test_detection_preserves_transparent_mask_preview(tmp_path):
    c, provider, _ = setup(tmp_path, enabled=True, lifetime_budget_usd=1)
    cutout = Image.new('RGBA', (4, 4), (255, 0, 0, 0))
    cutout.putpixel((1, 1), (255, 0, 0, 255))
    output = BytesIO()
    cutout.save(output, 'PNG')
    preview = 'data:image/png;base64,' + base64.b64encode(output.getvalue()).decode()
    provider.detect = lambda _: [dict(category='top', preview=preview, prompt='top')]
    response = detect(c)
    assert response.status_code == 200
    raw = base64.b64decode(response.json()['items'][0]['preview'].split(',')[1])
    with Image.open(BytesIO(raw)) as image:
        assert image.mode == 'RGBA'
        assert image.getchannel('A').getextrema() == (0, 255)


def test_health_auth_and_default_disabled(tmp_path):
    c, p, _ = setup(tmp_path)
    assert c.post('/api/health', headers={'Authorization': 'Bearer wrong'}).status_code == 401
    assert c.post('/api/health').json()['enabled'] is False
    assert c.post('/api/health').status_code == 200
    assert detect(c).status_code == 503
    assert p.detect_calls == 0
