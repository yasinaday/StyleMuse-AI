"""Actual authenticated HTTP billing contract; all Publisher traffic is fixture-only."""
import sqlite3
import pytest
from test_android_auth import case


def configure(monkeypatch):
    monkeypatch.setenv('STYLEMUSE_PLAY_PACKAGE', 'test.app')
    monkeypatch.setenv('STYLEMUSE_PLAY_CATALOG', '{"tokens_10":10}')
    monkeypatch.setenv('STYLEMUSE_PLAY_ACCOUNT_SECRET', 'x'*32)
    monkeypatch.setenv('STYLEMUSE_PLAY_SIGNING_SHA256', 'ab'*32)
    import play_billing as billing
    class Publisher:
        fail = False
        calls = 0
        def get(self, *args):
            return dict(purchaseState=0, consumptionState=0, quantity=1,
                        obfuscatedExternalAccountId=billing.account_id('google:android-user', b'x'*32))
        def consume(self, *args):
            self.calls += 1
            if self.fail: raise RuntimeError('SECRET')
    publisher = Publisher()
    monkeypatch.setattr(billing, 'GooglePublisher', lambda: publisher)
    return publisher


def login(c):
    assert c.post('/api/auth/google/android', json={'credential':'signed'}).status_code == 200


def test_billing_routes_fail_closed_and_require_identity(case):
    c, _, _ = case
    assert c.post('/api/billing/play/config',json={}).status_code == 403
    login(c)
    assert c.post('/api/billing/play/config',json={}).status_code == 503
    assert c.post('/api/billing/play/verify',json={'product_id':'tokens_10','purchase_token':'secret'}).status_code == 503


def test_billing_route_credit_retry_dedup_and_origin(case, monkeypatch, tmp_path):
    c, claims, _ = case
    publisher = configure(monkeypatch)
    login(c)
    config = c.post('/api/billing/play/config',json={})
    assert config.status_code == 200, config.text
    assert config.json()['product_ids'] == ['tokens_10']
    assert len(config.json()['account_id']) == 64
    payload = {'product_id':'tokens_10','purchase_token':'SECRET-token'}
    publisher.fail = True
    r = c.post('/api/billing/play/verify',json=payload)
    assert r.status_code == 200, r.text
    assert r.json() == {'status':'credited','consumed':False,'balance':10}
    publisher.fail = False
    assert c.post('/api/billing/play/verify',json=payload).json()['consumed'] is True
    assert c.post('/api/billing/play/verify',json=payload).json()['balance'] == 10
    assert c.post('/api/billing/play/verify',json=payload,headers={'Origin':'https://evil.invalid'}).status_code == 403
    assert c.post('/api/billing/play/verify',json={**payload,'amount':999}).status_code == 422
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT count(*) FROM play_receipts').fetchone()[0] == 1
        assert 'SECRET' not in str(db.execute('SELECT * FROM play_receipts').fetchall())
    c.post('/api/auth/logout'); c.post('/api/session')
    claims['sub'] = 'other'
    login(c)
    r = c.post('/api/billing/play/verify',json=payload)
    assert r.status_code == 422
    assert 'SECRET' not in r.text


def test_billing_credentials_unavailable_never_grants(case, monkeypatch, tmp_path):
    c, _, _ = case
    configure(monkeypatch)
    import play_billing
    def unavailable():
        raise RuntimeError('SECRET-ADC')
    monkeypatch.setattr(play_billing, 'GooglePublisher', unavailable)
    login(c)
    r = c.post('/api/billing/play/verify', json={'product_id':'tokens_10','purchase_token':'SECRET'})
    assert r.status_code == 503 and 'SECRET' not in r.text
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT count(*) FROM style_tokens').fetchone()[0] == 0
        assert db.execute('SELECT count(*) FROM play_receipts').fetchone()[0] == 0


@pytest.mark.parametrize('field,value', [('STYLEMUSE_PLAY_CATALOG','{}'),('STYLEMUSE_PLAY_SIGNING_SHA256',''),('STYLEMUSE_PLAY_ACCOUNT_SECRET','')])
def test_billing_missing_config_never_constructs_publisher(case,monkeypatch,field,value):
    c, _, _ = case
    configure(monkeypatch)
    monkeypatch.setenv(field,value)
    import play_billing
    monkeypatch.setattr(play_billing,'GooglePublisher',lambda: pytest.fail('must not construct transport'))
    login(c)
    assert c.post('/api/billing/play/config',json={}).status_code == 503
