"""Offline, fixture-only paid admission regressions; no real provider calls."""
import sqlite3
import pytest
from fastapi.testclient import TestClient
import app as api
from test_api import Provider, image
from test_oauth import CONFIG, HEADERS, login


def client(tmp_path, monkeypatch, provider=None, **settings):
    p = provider or Provider()
    c = TestClient(api.create_app(dict(CONFIG, enabled=True, lifetime_budget_usd=1,
        db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'), **settings), p), base_url='https://testserver')
    assert login(c, monkeypatch).status_code == 303
    return c, p

class FundedProvider(Provider):
    """Explicitly synthetic balance for offline admission tests."""
    balance = 10.0
    def credit_available_usd(self, action):
        return self.balance


def test_detect_requires_server_quote_and_spends_it_once(tmp_path, monkeypatch):
    c, p = client(tmp_path, monkeypatch, FundedProvider())
    inputs = dict(image=image(), request_id='quoted-detect')
    bare = c.post('/api/detect', headers=HEADERS, json=dict(inputs, confirmed=True, max_total_usd=.05))
    assert bare.status_code == 403
    assert p.detect_calls == 0
    quote = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs))
    assert quote.status_code == 200, quote.text
    q = quote.json()
    assert q['estimated_cost_usd'] == .05
    assert 0 < q['expires_in_seconds'] <= 120
    approved = dict(inputs, confirmed=True, max_total_usd=q['estimated_cost_usd'], quote_id=q['quote_id'])
    result = c.post('/api/detect', headers=HEADERS, json=approved)
    assert result.status_code == 200, result.text
    assert p.detect_calls == 1
    assert c.post('/api/detect', headers=HEADERS, json=approved).status_code == 403
    assert p.detect_calls == 1
@pytest.mark.parametrize('balance', [None, 0, .049, float('nan'), float('inf'), True, '10'])
def test_unverified_or_insufficient_credit_blocks_quote_and_submission(tmp_path, monkeypatch, balance):
    c, p = client(tmp_path, monkeypatch, FundedProvider())
    inputs = dict(image=image(), request_id='credit')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs)).json()
    p.balance = balance
    denied = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs))
    assert denied.status_code == 402
    denied = c.post('/api/detect', headers=HEADERS, json=dict(inputs, quote_id=q['quote_id'], confirmed=True, max_total_usd=.05))
    assert denied.status_code == 402
    assert p.detect_calls == 0
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT count(*) FROM jobs').fetchone()[0] == 0


def test_application_admission_has_no_global_or_owner_ceiling_preserves_history(tmp_path, monkeypatch):
    from store import Store
    s = api.Settings(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'), lifetime_budget_usd=1)
    history = Store(s)
    with history.tx() as db:
        db.execute('UPDATE ledger SET reserved=2000000, ceiling=1000000')
        db.execute("INSERT INTO owner_ledger VALUES('github:12345',2000000,750000)")
    c, p = client(tmp_path, monkeypatch, FundedProvider())
    with history.tx() as db:
        assert tuple(db.execute('SELECT ceiling,reserved FROM owner_ledger').fetchone()) == (750000, 2000000)
    inputs = dict(image=image(), request_id='beyond-old-caps')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs)).json()
    result = c.post('/api/detect', headers=HEADERS, json=dict(inputs, quote_id=q['quote_id'], confirmed=True, max_total_usd=.05))
    assert result.status_code == 200, result.text
    with history.tx() as db:
        assert tuple(db.execute('SELECT ceiling,reserved FROM ledger').fetchone()) == (1000000, 2050000)
        assert tuple(db.execute('SELECT ceiling,reserved FROM owner_ledger').fetchone()) == (750000, 2050000)
        assert db.execute('SELECT count(*) FROM budget_periods').fetchone()[0] == 0


def test_generate_quote_binds_selection_cost_and_is_one_use(tmp_path, monkeypatch):
    c, p = client(tmp_path, monkeypatch, FundedProvider())
    inputs = dict(image=image(), request_id='generate-source')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs)).json()
    detected = c.post('/api/detect', headers=HEADERS, json=dict(inputs, quote_id=q['quote_id'], confirmed=True, max_total_usd=.05)).json()
    selection = dict(job_id=detected['job_id'], item_ids=[detected['items'][0]['id']])
    assert c.post('/api/generate', headers=HEADERS, json=dict(selection, confirmed=True, max_total_usd=.1)).status_code == 403
    assert p.generate_calls == 0
    quote = c.post('/api/quote', headers=HEADERS, json=dict(action='generate', inputs=selection))
    assert quote.status_code == 200, quote.text
    q = quote.json()
    assert q['estimated_cost_usd'] == .1
    approved = dict(selection, quote_id=q['quote_id'], confirmed=True, max_total_usd=.1)
    result = c.post('/api/generate', headers=HEADERS, json=approved)
    assert result.status_code == 200, result.text
    assert p.generate_calls == 1
    assert c.post('/api/generate', headers=HEADERS, json=approved).status_code == 403
    assert p.generate_calls == 1


def test_real_credit_adapter_reads_fal_only_and_never_infers_replicate_credit():
    import httpx
    from providers import RealProviders
    calls = []
    def transport(request):
        calls.append(request)
        assert request.method == 'GET'
        assert str(request.url) == 'https://api.fal.ai/v1/account/billing?expand=credits'
        assert request.headers['authorization'] == 'Key fixture-fal'
        return httpx.Response(200, json={'credits': {'current_balance': 9.36, 'currency': 'USD'}})
    p = RealProviders('fixture-replicate', 'fixture-fal', transport=httpx.MockTransport(transport))
    try:
        assert hasattr(p, 'credit_available_usd'), 'Read-only credit preflight missing'
        assert p.credit_available_usd('detect') is None
        assert not calls
        assert p.credit_available_usd('generate') == 9.36
        assert len(calls) == 1
    finally:
        p.close()


def test_environment_provider_construction_does_not_require_legacy_cap(tmp_path, monkeypatch):
    import providers
    for key, value in CONFIG.items():
        monkeypatch.setenv('STYLEMUSE_'+key.upper(), value)
    monkeypatch.setenv('STYLEMUSE_ENABLED', 'true')
    monkeypatch.setenv('STYLEMUSE_LIFETIME_BUDGET_USD', '0')
    monkeypatch.setenv('STYLEMUSE_DB_PATH', str(tmp_path/'db'))
    monkeypatch.setenv('STYLEMUSE_STORAGE_DIR', str(tmp_path/'images'))
    p = FundedProvider()
    monkeypatch.setattr(providers.RealProviders, 'from_env', lambda: p)
    c = TestClient(api.create_app_from_env(), base_url='https://testserver')
    assert login(c, monkeypatch).status_code == 303
    quoted = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=dict(image=image(), request_id='zero-legacy-cap')))
    assert quoted.status_code == 200, quoted.text
    assert p.detect_calls == 0


def test_generation_rechecks_real_credit_before_each_paid_submission(tmp_path, monkeypatch):
    c, p = client(tmp_path, monkeypatch, FundedProvider())
    p.detect = lambda _: [dict(category='top', preview=image(), prompt='top') for _ in range(2)]
    inputs = dict(image=image(), request_id='credit-changes')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs)).json()
    job = c.post('/api/detect', headers=HEADERS, json=dict(inputs, confirmed=True, max_total_usd=.05, quote_id=q['quote_id'])).json()
    selection = dict(job_id=job['job_id'], item_ids=[i['id'] for i in job['items']])
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='generate', inputs=selection)).json()
    original = p.generate
    def generate(*args):
        result = original(*args)
        p.balance = 0
        return result
    p.generate = generate
    denied = c.post('/api/generate', headers=HEADERS, json=dict(selection, confirmed=True, max_total_usd=.2, quote_id=q['quote_id']))
    assert denied.status_code == 502
    assert p.generate_calls == 1
    with sqlite3.connect(tmp_path/'db') as db:
        assert sorted(r[0] for r in db.execute("SELECT state FROM operations WHERE id LIKE 'generate:%'")) == ['released','spent']


@pytest.mark.parametrize('tamper', ['image', 'request_id', 'cost', 'expired', 'session', 'confirmation', 'fractional_cost'])
def test_detect_quote_rejects_any_changed_binding_without_submission(tmp_path, monkeypatch, tamper):
    c, p = client(tmp_path, monkeypatch, FundedProvider())
    inputs = dict(image=image(), request_id='binding')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs)).json()
    payload = dict(inputs, quote_id=q['quote_id'], confirmed=True, max_total_usd=.05)
    if tamper == 'image':
        from providers import png_uri
        from PIL import Image
        payload['image'] = png_uri(Image.new('RGB', (4,4), 'blue'))
    elif tamper == 'request_id':
        payload['request_id'] = 'different'
    elif tamper == 'cost':
        payload['max_total_usd'] = 5
    elif tamper == 'fractional_cost':
        payload['max_total_usd'] = .04999999999999
    elif tamper == 'confirmation':
        payload['confirmed'] = False
    elif tamper == 'expired':
        with sqlite3.connect(tmp_path/'db') as db:
            db.execute('UPDATE payment_quotes SET expires=0')
    elif tamper == 'session':
        c = TestClient(c.app, base_url='https://testserver')
        assert login(c, monkeypatch).status_code == 303
    denied = c.post('/api/detect', headers=HEADERS, json=payload)
    assert denied.status_code == 403, denied.text
    assert p.detect_calls == 0
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT count(*) FROM jobs').fetchone()[0] == 0


def test_quote_concurrent_replay_submits_exactly_once(tmp_path, monkeypatch):
    from concurrent.futures import ThreadPoolExecutor
    c, p = client(tmp_path, monkeypatch, FundedProvider())
    inputs = dict(image=image(), request_id='concurrent')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs)).json()
    payload = dict(inputs, quote_id=q['quote_id'], confirmed=True, max_total_usd=.05)
    with ThreadPoolExecutor(max_workers=2) as pool:
        statuses = list(pool.map(lambda _: c.post('/api/detect', headers=HEADERS, json=payload).status_code, range(2)))
    assert sorted(statuses) == [200, 403]
    assert p.detect_calls == 1


@pytest.mark.parametrize('credits', [{}, {'current_balance':True,'currency':'USD'},
    {'current_balance':10,'currency':'EUR'}, {'current_balance':'9.36','currency':'USD'},
    {'current_balance':-1,'currency':'USD'}])
def test_fal_credit_malformed_or_wrong_currency_fails_closed(credits):
    import httpx
    from providers import RealProviders
    seen=[]
    def transport(request):
        seen.append(request.method)
        return httpx.Response(200, json={'credits':credits})
    p=RealProviders('r','f',transport=httpx.MockTransport(transport))
    try:
        assert p.credit_available_usd('generate') is None
        assert seen == ['GET']
    finally:
        p.close()


def test_generation_quote_binds_actual_stored_provider_reference(tmp_path, monkeypatch):
    c, p = client(tmp_path, monkeypatch, FundedProvider())
    inputs = dict(image=image(), request_id='source-binding')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs)).json()
    job = c.post('/api/detect', headers=HEADERS, json=dict(inputs, confirmed=True, max_total_usd=.05, quote_id=q['quote_id'])).json()
    selection = dict(job_id=job['job_id'], item_ids=[job['items'][0]['id']])
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='generate', inputs=selection)).json()
    from PIL import Image
    from providers import png_uri
    with sqlite3.connect(tmp_path/'db') as db:
        db.execute('UPDATE jobs SET original=?', (png_uri(Image.new('RGB',(4,4),'blue')),))
    result = c.post('/api/generate', headers=HEADERS, json=dict(selection, confirmed=True, max_total_usd=.1, quote_id=q['quote_id']))
    assert result.status_code == 403
    assert p.generate_calls == 0


def test_private_bearer_can_never_authorize_paid_inference(tmp_path):
    p = Provider()
    c = TestClient(api.create_app(dict(access_token='legacy', enabled=True,
        db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images')), p))
    r = c.post('/api/detect', headers={'Authorization': 'Bearer legacy'},
        json=dict(image=image(), request_id='x', confirmed=True, max_total_usd=1))
    assert r.status_code in (401, 403)
    assert p.detect_calls == 0
