"""Offline manual-credit evidence; identities/balances here are fixtures."""
import sqlite3
import time
import pytest
import app as api
from store import Store, units


def store(tmp_path):
    return Store(api.Settings(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images')))


def test_manual_snapshot_is_identity_bound_timestamped_expiring_and_debited(tmp_path):
    s = store(tmp_path)
    before = time.time()
    s.record_manual_credit('fixture-snapshot', 'user:fixture-owner', '.92', 'User Billing confirmation 2026-11-10')
    credit = s.manual_credit('user:fixture-owner')
    assert before <= credit['recorded_at'] <= time.time()
    assert credit['source'] == 'manual_non_realtime'
    assert credit['available_usd'] == .92
    assert credit['overspend_risk'] is True
    assert s.manual_credit('user:other-owner') is None
    with s.tx() as db:
        s.reserve(db, units('.05'), enforce_budget=False)
        s.record_operation(db, 'detect:fixture-job', units('.05'))
    s.mark_submitted('detect:fixture-job', manual_credit_id='fixture-snapshot')
    s.finish_operation('detect:fixture-job', success=False)
    s.release()
    assert store(tmp_path).manual_credit('user:fixture-owner')['available_usd'] == .87
    with pytest.raises(RuntimeError):
        s.mark_submitted('detect:fixture-job', manual_credit_id='fixture-snapshot')
    with s.tx() as db:
        db.execute('UPDATE manual_provider_credit SET expires=0')
    assert s.manual_credit('user:fixture-owner') is None


def test_manual_fallback_quote_discloses_risk_and_preserves_single_use(tmp_path, monkeypatch):
    from test_paid_quotes import client, FundedProvider
    from test_oauth import HEADERS
    from test_api import image
    class ManualProvider(FundedProvider):
        balance = None
        def replicate_account(self):
            return 'user:fixture-owner'
    c, p = client(tmp_path, monkeypatch, ManualProvider())
    store(tmp_path).record_manual_credit('fixture-snapshot', 'user:fixture-owner', '.92', 'fixture Billing evidence')
    health = c.post('/api/health', headers=HEADERS).json()
    assert health['app_spending_ceiling_usd'] is None
    assert health['historical_budget_metadata'] is True
    inputs = dict(image=image(), request_id='manual-fixture')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs))
    assert q.status_code == 200, q.text
    credit = q.json()['provider_credit']
    assert credit['source'] == 'manual_non_realtime' and credit['overspend_risk']
    assert credit['available_usd'] == .92
    approved = dict(inputs, confirmed=True, quote_id=q.json()['quote_id'], max_total_usd=.05)
    assert c.post('/api/detect', headers=HEADERS, json=approved).status_code == 200
    assert c.post('/api/detect', headers=HEADERS, json=approved).status_code == 403
    assert p.detect_calls == 1
    assert store(tmp_path).manual_credit('user:fixture-owner')['available_usd'] == .87


def test_real_account_is_read_only_and_not_a_balance_api():
    import httpx
    from providers import RealProviders
    seen = []
    def transport(request):
        seen.append((request.method, str(request.url)))
        assert request.headers['authorization'] == 'Bearer fixture-token'
        return httpx.Response(200, json={'type': 'user', 'username': 'fixture-owner', 'name': 'Fixture'})
    p = RealProviders('fixture-token', 'fixture-fal', transport=httpx.MockTransport(transport))
    try:
        assert p.replicate_account() == 'user:fixture-owner'
        assert seen == [('GET', 'https://api.replicate.com/v1/account')]
        assert p.credit_available_usd('detect') is None
        assert len(seen) == 1
    finally:
        p.close()


def test_operator_enrollment_only_reads_identity_and_does_not_submit(tmp_path, monkeypatch, capsys):
    import importlib.util
    assert importlib.util.find_spec('record_replicate_balance'), 'Operator enrollment command missing'
    import record_replicate_balance as command
    class Provider:
        def replicate_account(self):
            return 'user:fixture-owner'
        def close(self):
            pass
    monkeypatch.setenv('STYLEMUSE_ENABLED', 'false')
    monkeypatch.setenv('STYLEMUSE_DB_PATH', str(tmp_path/'db'))
    monkeypatch.setenv('STYLEMUSE_STORAGE_DIR', str(tmp_path/'images'))
    monkeypatch.setattr(command.RealProviders, 'from_env', lambda: Provider())
    monkeypatch.setattr('sys.argv', ['record_replicate_balance.py', '--snapshot-id', 'fixture-command', '--amount', '.92', '--evidence', 'fixture user Billing statement'])
    command.main()
    assert store(tmp_path).manual_credit('user:fixture-owner')['available_usd'] == .92
    assert 'manual_non_realtime' in capsys.readouterr().out
    monkeypatch.setenv('STYLEMUSE_ENABLED', 'true')
    with pytest.raises(SystemExit):
        command.main()


@pytest.mark.parametrize('refresh_race', [False, True])
def test_quote_binds_manual_snapshot_and_refresh_does_not_reauthorize_old_quote(tmp_path, monkeypatch, refresh_race):
    from test_paid_quotes import client, FundedProvider
    from test_oauth import HEADERS
    from test_api import image
    class ManualProvider(FundedProvider):
        balance = None
        def replicate_account(self):
            return 'user:fixture-owner'
    c, p = client(tmp_path, monkeypatch, ManualProvider())
    s = store(tmp_path)
    s.record_manual_credit('old', 'user:fixture-owner', '.92', 'fixture old statement')
    inputs = dict(image=image(), request_id='replaced-snapshot')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=inputs)).json()
    if refresh_race:
        original = Store.manual_credit
        def refresh_after_read(self, account):
            credit = original(self, account)
            s.record_manual_credit('new', 'user:fixture-owner', '.92', 'fixture refreshed statement')
            return credit
        monkeypatch.setattr(Store, 'manual_credit', refresh_after_read)
    else:
        s.record_manual_credit('new', 'user:fixture-owner', '.92', 'fixture refreshed statement')
    result = c.post('/api/detect', headers=HEADERS, json=dict(inputs, confirmed=True, max_total_usd=.05, quote_id=q['quote_id']))
    assert result.status_code == 403, result.text
    assert p.detect_calls == 0


@pytest.mark.parametrize('problem', ['missing', 'wrong_account', 'expired', 'insufficient', 'identity_failure'])
def test_manual_evidence_fails_closed_without_any_job_or_provider_submission(tmp_path, monkeypatch, problem):
    from test_paid_quotes import client, FundedProvider
    from test_oauth import HEADERS
    from test_api import image
    class ManualProvider(FundedProvider):
        balance = None
        def replicate_account(self):
            if problem == 'identity_failure':
                raise RuntimeError('fixture account GET failure')
            return 'user:wrong' if problem == 'wrong_account' else 'user:fixture-owner'
    c, p = client(tmp_path, monkeypatch, ManualProvider())
    s = store(tmp_path)
    if problem != 'missing':
        s.record_manual_credit('fixture', 'user:fixture-owner', '.01' if problem == 'insufficient' else '.92', 'fixture statement')
    if problem == 'expired':
        with s.tx() as db:
            db.execute('UPDATE manual_provider_credit SET expires=0')
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='detect', inputs=dict(image=image(), request_id='fail-closed')))
    assert q.status_code == 402
    assert p.detect_calls == 0
    with s.tx() as db:
        assert db.execute('SELECT count(*) FROM jobs').fetchone()[0] == 0
        assert db.execute('SELECT count(*) FROM payment_quotes').fetchone()[0] == 0
        assert db.execute('SELECT count(*) FROM manual_provider_debits').fetchone()[0] == 0


def test_manual_debit_is_writer_serialized_insufficient_and_audit_failure_roll_back(tmp_path):
    s = store(tmp_path)
    s.record_manual_credit('fixture', 'user:fixture-owner', '.05', 'fixture statement')
    with s.tx() as db:
        s.record_operation(db, 'detect:one', units('.05'))
        s.record_operation(db, 'detect:two', units('.05'))
    from concurrent.futures import ThreadPoolExecutor
    def submit(op):
        try:
            store(tmp_path).mark_submitted(op, manual_credit_id='fixture')
            return 'submitted'
        except RuntimeError:
            return 'denied'
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(submit, ['detect:one', 'detect:two'])) == ['denied', 'submitted']
    assert s.manual_credit('user:fixture-owner')['available_usd'] == 0
    s.record_manual_credit('new', 'user:fixture-owner', '.05', 'fixture refreshed statement')
    with s.tx() as db:
        db.execute("CREATE TRIGGER fixture_fail_debit BEFORE INSERT ON manual_provider_debits BEGIN SELECT RAISE(ABORT, 'fixture disk fault'); END")
        pending = db.execute("SELECT id FROM operations WHERE state='reserved'").fetchone()[0]
    with pytest.raises(sqlite3.DatabaseError):
        s.mark_submitted(pending, manual_credit_id='new')
    assert s.manual_credit('user:fixture-owner')['available_usd'] == .05
    with s.tx() as db:
        assert db.execute('SELECT state FROM operations WHERE id=?', (pending,)).fetchone()[0] == 'reserved'


def test_snapshot_reenrollment_cannot_refresh_time_or_reset_held_estimates(tmp_path):
    s = store(tmp_path)
    s.record_manual_credit('fixture', 'user:fixture-owner', '.92', 'fixture statement')
    before = s.manual_credit('user:fixture-owner')
    with s.tx() as db:
        s.record_operation(db, 'detect:one', units('.05'))
    s.mark_submitted('detect:one', manual_credit_id='fixture')
    s.record_manual_credit('fixture', 'user:fixture-owner', '.92', 'fixture statement')
    after = s.manual_credit('user:fixture-owner')
    assert after['recorded_at'] == before['recorded_at']
    assert after['expires_at'] == before['expires_at']
    assert after['available_usd'] == .87
    with pytest.raises(ValueError):
        s.record_manual_credit('fixture', 'user:fixture-owner', '99', 'fixture statement')
