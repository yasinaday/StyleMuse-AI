"""Offline accounting: monetary values are admission estimates, not invoices."""
from app import Settings
from store import Store, units
import pytest


@pytest.mark.parametrize('success', [False, True])
def test_submitted_charge_is_retained_and_restart_never_releases(tmp_path, success):
    store = make_store(tmp_path)
    with store.tx() as db:
        store.reserve(db, units(.1), owner='github:1')
        store.record_operation(db, 'op', units(.1), 'github:1')
    store.mark_submitted('op')
    store.finish_operation('op', success=success)
    store.finish_operation('op', success=False)
    reopened = make_store(tmp_path)
    assert reopened.costs() == dict(reserved_usd=.1, lifetime_budget_usd=.5,
        spent_usd=.1 if success else 0, pending_usd=0 if success else .1, remaining_usd=.4)
    with reopened.tx() as db:
        assert db.execute('SELECT reserved FROM owner_ledger').fetchone()[0] == units(.1)


def test_crashed_unsubmitted_reservation_is_not_automatically_refunded(tmp_path):
    store = make_store(tmp_path)
    with store.tx() as db:
        store.reserve(db, units(.1))
        store.record_operation(db, 'op', units(.1))
    reopened = make_store(tmp_path)
    assert reopened.costs()['pending_usd'] == .1
    with reopened.tx() as db:
        assert db.execute('SELECT busy FROM guard').fetchone()[0] == 1


@pytest.mark.parametrize('mode', ['preflight', 'timeout', 'http_error', 'malformed'])
def test_real_submission_boundary_accounting_offline(tmp_path, mode):
    import httpx
    from providers import RealProviders
    from test_api import image
    store = make_store(tmp_path)
    with store.tx() as db:
        store.reserve(db, units(.1))
        store.record_operation(db, 'op', units(.1))
    seen = []
    def transport(request):
        seen.append(request.method)
        with store.tx() as db:
            assert db.execute('SELECT state FROM operations').fetchone()[0] == 'submitted'
        if mode == 'timeout':
            raise httpx.ReadTimeout('fixture')
        return httpx.Response(403 if mode == 'http_error' else 200, json={})
    provider = RealProviders('', '' if mode == 'preflight' else 'fixture', transport=httpx.MockTransport(transport))
    try:
        with pytest.raises(Exception):
            provider.generate(image(), {'category':'top'}, before_submit=lambda: store.mark_submitted('op'))
        store.finish_operation('op', success=False)
        assert seen == ([] if mode == 'preflight' else ['POST'])
        assert store.costs()['reserved_usd'] == (0 if mode == 'preflight' else .1)
    finally:
        provider.close()


def test_submit_audit_failure_prevents_any_provider_post(tmp_path):
    import httpx
    from providers import RealProviders
    from test_api import image
    seen = []
    provider = RealProviders('', 'fixture', transport=httpx.MockTransport(lambda request: seen.append(request)))
    def fail():
        raise RuntimeError('audit write failed')
    try:
        with pytest.raises(RuntimeError, match='audit write failed'):
            provider.generate(image(), {'category':'top'}, before_submit=fail)
        assert seen == []
    finally:
        provider.close()


def make_store(tmp_path):
    return Store(Settings(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'), lifetime_budget_usd=.5))


def test_operation_release_requires_durable_unsubmitted_evidence(tmp_path):
    store = make_store(tmp_path)
    with store.tx() as db:
        store.reserve(db, units(.1), owner='github:1')
        store.record_operation(db, 'op', units(.1), 'github:1')
    assert store.costs()['pending_usd'] == .1
    store.finish_operation('op', success=False)
    store.finish_operation('op', success=False)
    assert store.costs()['reserved_usd'] == 0
    with store.tx() as db:
        assert db.execute('SELECT reserved FROM owner_ledger').fetchone()[0] == 0
        assert db.execute('SELECT state FROM operations').fetchone()[0] == 'released'
    store.release()


def test_real_unknown_credit_blocks_before_reservation_or_job(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient
    from app import create_app
    from providers import RealProviders
    from test_api import image
    provider = RealProviders('', '')
    from test_oauth import CONFIG, HEADERS, login
    client = TestClient(create_app(dict(CONFIG, enabled=True,
        lifetime_budget_usd=.5, db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images')), provider), base_url='https://testserver')
    assert login(client, monkeypatch).status_code == 303
    client.headers.update(HEADERS)
    payload = dict(image=image(), request_id='preflight', confirmed=True, max_total_usd=.05)
    assert client.post('/api/detect', json=payload).status_code == 402
    health = client.post('/api/health').json()
    assert health['reserved_usd'] == health['pending_usd'] == health['spent_usd'] == 0
    assert health['remaining_usd'] == .5
    assert client.post('/api/detect', json=payload).status_code == 402
    with make_store(tmp_path).tx() as db:
        assert db.execute('SELECT count(*) FROM jobs').fetchone()[0] == 0
    provider.close()


def test_generation_partial_failure_releases_only_unstarted_items(tmp_path):
    from test_api import setup, detect, image
    client, provider, _ = setup(tmp_path, enabled=True, lifetime_budget_usd=.5)
    provider.detect = lambda _: [dict(category='top', prompt='top', preview=image()) for _ in range(3)]
    job = detect(client).json()
    calls = []
    def generate(original, item):
        calls.append(item)
        if len(calls) == 2:
            raise RuntimeError('ambiguous')
        return image()
    provider.generate = generate
    payload = dict(job_id=job['job_id'], item_ids=[i['id'] for i in job['items']], confirmed=True, max_total_usd=.3)
    assert client.post('/api/generate', json=payload).status_code == 502
    assert len(calls) == 2
    health = client.post('/api/health').json()
    assert health['reserved_usd'] == .25
    assert health['spent_usd'] == .15
    assert health['pending_usd'] == .1
    assert health['remaining_usd'] == .25
    assert client.post('/api/generate', json=payload).status_code == 409
    assert len(calls) == 2


def test_cancelled_preflight_releases_and_propagates_cancellation(tmp_path):
    from app import create_app, DetectRequest
    from providers import RealProviders
    from test_api import image
    from offline_test_support import PaidFixtureClient, offline_app
    from starlette.requests import Request
    from test_oauth import HEADERS
    class Cancelled(BaseException):
        pass
    provider = RealProviders('fixture', '')
    def cancel(*args, **kwargs):
        raise Cancelled()
    provider.http.request = cancel
    app = offline_app(dict(access_token='secret', enabled=True, lifetime_budget_usd=.5,
        db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images')), provider)
    client = PaidFixtureClient(app)
    inputs = dict(image=image(), request_id='cancelled')
    quote = client.post('/api/quote', json={'action':'detect','inputs':inputs}).json()
    cookie = client.cookies.get('__Host-stylemuse_session')
    request = Request({'type':'http', 'headers':[(b'origin', HEADERS['Origin'].encode()),
        (b'cookie', ('__Host-stylemuse_session='+cookie).encode())]})
    endpoint = next(route.endpoint for route in app.routes if route.path == '/api/detect')
    try:
        with pytest.raises(Cancelled):
            endpoint(DetectRequest(**inputs, confirmed=True, max_total_usd=.05, quote_id=quote['quote_id']), request, None)
        store = make_store(tmp_path)
        assert store.costs()['reserved_usd'] == 0
        with store.tx() as db:
            assert db.execute('SELECT busy FROM guard').fetchone()[0] == 0
    finally:
        provider.close()


def test_historical_reservations_are_preserved_as_unknown_pending(tmp_path):
    store = make_store(tmp_path)
    with store.tx() as db:
        store.reserve(db, units(.1))
    store.release()
    reopened = make_store(tmp_path)
    assert reopened.costs() == dict(reserved_usd=.1, lifetime_budget_usd=.5,
                                   spent_usd=0, pending_usd=.1, remaining_usd=.4)
