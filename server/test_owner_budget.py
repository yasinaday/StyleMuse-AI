"""Durable owner accounting tests; SQLite only, no provider calls."""
import pytest
from fastapi import HTTPException
from app import Settings
from store import Store, units


@pytest.mark.parametrize('values', [{'owner_rate_limit':0}, {'owner_rate_limit':True},
    {'owner_rate_window_seconds':float('inf')}, {'owner_lifetime_budget_usd':float('nan')}])
def test_invalid_owner_admission_config_rejected(tmp_path, values):
    from app import create_app
    with pytest.raises(ValueError):
        create_app(dict(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'), **values))


def test_owner_cap_survives_restart_cannot_increase_and_preserves_global(tmp_path):
    assert hasattr(Settings, 'owner_lifetime_budget_usd'), 'Per-owner cap is missing'
    s = Settings(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'),
        lifetime_budget_usd=.5, owner_lifetime_budget_usd=.1)
    store = Store(s)
    with store.tx() as db:
        store.reserve(db, units(.1), owner='github:12345')
    store.release()
    s.owner_lifetime_budget_usd = .5
    restarted = Store(s)
    with pytest.raises(HTTPException) as exc:
        with restarted.tx() as db:
            restarted.reserve(db, units(.01), owner='github:12345')
    assert exc.value.status_code == 402
    assert exc.value.detail == 'owner_budget_exceeded'
    assert restarted.costs()['reserved_usd'] == .1
    with restarted.tx() as db:
        assert db.execute('SELECT reserved FROM owner_ledger WHERE owner=?', ('github:12345',)).fetchone()[0] == units(.1)
        assert db.execute('SELECT busy FROM guard').fetchone()[0] == 0

def test_startup_does_not_rewrite_historical_owner_ceiling(tmp_path):
    s = Settings(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'), lifetime_budget_usd=.5)
    first = Store(s)
    with first.tx() as db:
        first.reserve(db, units(.1), owner='github:12345')
    first.release()
    s.owner_lifetime_budget_usd = .1
    Store(s)
    s.owner_lifetime_budget_usd = .5
    reopened = Store(s)
    with reopened.tx() as db:
        assert db.execute('SELECT ceiling FROM owner_ledger').fetchone()[0] == units(.5)
        reopened.reserve(db, units(.01), owner='github:12345', enforce_budget=False)


def test_owner_rate_limit_survives_restart_and_rolls_back_all_admission(tmp_path, monkeypatch):
    assert hasattr(Settings, 'owner_rate_limit'), 'Durable owner rate configuration missing'
    import store as storage
    now = [1000.0]
    monkeypatch.setattr(storage.time, 'time', lambda: now[0])
    s = Settings(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'),
        lifetime_budget_usd=.5, owner_rate_limit=1, owner_rate_window_seconds=60)
    first = Store(s)
    with first.tx() as db:
        first.reserve(db, units(.05), owner='github:12345')
    first.release()
    second = Store(s)
    now[0] = 1059
    with pytest.raises(HTTPException) as exc:
        with second.tx() as db:
            second.reserve(db, units(.05), owner='github:12345')
    assert exc.value.status_code == 429
    assert exc.value.detail == 'owner_rate_limited'
    assert second.costs()['reserved_usd'] == .05
    with second.tx() as db:
        assert db.execute('SELECT busy FROM guard').fetchone()[0] == 0
    now[0] = 1060
    with second.tx() as db:
        second.reserve(db, units(.05), owner='github:12345')
    second.release()
    assert second.costs()['reserved_usd'] == .1
