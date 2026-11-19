"""Offline: intentionally imports no app/provider modules."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import pytest
from store import Store


def module():
    path = Path(__file__).with_name('play_billing.py')
    assert path.exists(), 'Play billing implementation missing'
    spec = importlib.util.spec_from_file_location('billing_under_test', path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def setup(tmp_path):
    m = module()
    store = Store(SimpleNamespace(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'files'), lifetime_budget_usd=1))
    class Publisher:
        def __init__(self):
            self.calls = 0
            self.fail = False
            self.result = {'purchaseState': 0, 'consumptionState': 0, 'quantity': 1,
                           'obfuscatedExternalAccountId': m.account_id('user:one', b'x'*32)}
        def get(self, package, product, token):
            return dict(self.result)
        def consume(self, package, product, token):
            self.calls += 1
            if self.fail: raise OSError('offline')
            self.result['consumptionState'] = 1
    publisher = Publisher()
    service = m.PlayBilling(store, publisher, package='test.app', catalog={'tokens_10': 10},
                            account_secret=b'x'*32, signing_sha256='ab'*32)
    return m, store, publisher, service


def test_credit_replay_and_consumption(tmp_path):
    _, store, publisher, service = setup(tmp_path)
    assert service.verify('user:one', 'tokens_10', 'secret-token')['status'] == 'credited'
    assert store.style_balance('user:one') == 10
    assert service.verify('user:one', 'tokens_10', 'secret-token')['status'] == 'credited'
    assert store.style_balance('user:one') == 10
    assert publisher.calls == 1


@pytest.mark.parametrize('state,status', [(1,'cancelled'), (2,'pending')])
def test_not_purchased(tmp_path, state, status):
    _, store, publisher, service = setup(tmp_path)
    publisher.result['purchaseState'] = state
    assert service.verify('user:one', 'tokens_10', 'token')['status'] == status
    assert store.style_balance('user:one') == 0
    assert publisher.calls == 0


@pytest.mark.parametrize('field,value', [('obfuscatedExternalAccountId','wrong'), ('quantity',2), ('consumptionState',1), ('purchaseState',True)])
def test_reject_invalid_purchase(tmp_path, field, value):
    _, store, publisher, service = setup(tmp_path)
    publisher.result[field] = value
    with pytest.raises(ValueError): service.verify('user:one', 'tokens_10', 'token')
    assert store.style_balance('user:one') == 0


def test_consumption_failure_recovery(tmp_path):
    _, store, publisher, service = setup(tmp_path)
    publisher.fail = True
    assert not service.verify('user:one', 'tokens_10', 'token')['consumed']
    assert store.style_balance('user:one') == 10
    publisher.fail = False
    assert service.verify('user:one', 'tokens_10', 'token')['consumed']
    assert store.style_balance('user:one') == 10


def test_concurrent_replay(tmp_path):
    from concurrent.futures import ThreadPoolExecutor
    _, store, publisher, service = setup(tmp_path)
    publisher.consume = lambda *args: None
    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(lambda _: service.verify('user:one', 'tokens_10', 'token'), range(24)))
    assert store.style_balance('user:one') == 10


def test_credit_failure_rolls_back_receipt(tmp_path):
    _, store, publisher, service = setup(tmp_path)
    with store.tx() as db:
        db.execute("CREATE TRIGGER reject_credit BEFORE INSERT ON style_tokens BEGIN SELECT RAISE(ABORT, 'full'); END")
    with pytest.raises(Exception): service.verify('user:one', 'tokens_10', 'token')
    with store.tx() as db:
        assert db.execute('SELECT count(*) FROM play_receipts').fetchone()[0] == 0
    assert publisher.calls == 0


def test_configuration_fail_closed(tmp_path):
    m, store, publisher, _ = setup(tmp_path)
    for override in [dict(catalog={}), dict(signing_sha256=''), dict(account_secret=b''), dict(publisher=None)]:
        options = dict(package='test.app', catalog={'tokens_10':10}, account_secret=b'x'*32, signing_sha256='ab'*32, publisher=publisher)
        options.update(override)
        with pytest.raises(ValueError): m.PlayBilling(store, **options)


def test_ownership_conflict_even_if_publisher_account_changes(tmp_path):
    m, store, publisher, service = setup(tmp_path)
    service.verify('user:one', 'tokens_10', 'token')
    publisher.result['obfuscatedExternalAccountId'] = m.account_id('user:two', b'x'*32)
    with pytest.raises(ValueError, match='purchase_replay_conflict'):
        service.verify('user:two', 'tokens_10', 'token')
    assert store.style_balance('user:two') == 0
    assert store.style_balance('user:one') == 10


def test_no_app_import():
    # Collection of the full API suite imports app before this test runs;
    # test the module's import isolation in a genuinely fresh interpreter.
    import subprocess
    import sys
    result = subprocess.run([sys.executable, '-c',
        "import play_billing, sys; assert 'app' not in sys.modules; assert 'providers' not in sys.modules"],
        cwd=Path(__file__).parent, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
