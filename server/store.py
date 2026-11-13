"""SQLite writer-serialized admission and durable private job storage."""
import sqlite3
import os
import time
from pathlib import Path
from contextlib import contextmanager
from decimal import Decimal, ROUND_CEILING


def units(value):
    d = Decimal(str(value))
    if not d.is_finite() or d < 0:
        raise ValueError('invalid_cost')
    return int((d * 1000000).to_integral_value(rounding=ROUND_CEILING))


class Store:
    def __init__(self, settings):
        self.settings = settings
        p = Path(settings.db_path)
        p.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        Path(settings.storage_dir).mkdir(parents=True, exist_ok=True, mode=0o700)
        with self.tx() as db:
            db.executescript('''
            CREATE TABLE IF NOT EXISTS ledger(id INTEGER PRIMARY KEY CHECK(id=1), ceiling INTEGER NOT NULL, reserved INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY, owner TEXT NOT NULL, request_id TEXT NOT NULL, hash TEXT NOT NULL, state TEXT NOT NULL, original TEXT, result TEXT, expires REAL NOT NULL, UNIQUE(owner,request_id));
            CREATE TABLE IF NOT EXISTS claims(job TEXT NOT NULL,item TEXT NOT NULL,state TEXT NOT NULL,image TEXT,PRIMARY KEY(job,item));
            CREATE TABLE IF NOT EXISTS owner_ledger(owner TEXT PRIMARY KEY, reserved INTEGER NOT NULL, ceiling INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS owner_rate(owner TEXT NOT NULL, admitted REAL NOT NULL);
            CREATE INDEX IF NOT EXISTS owner_rate_lookup ON owner_rate(owner,admitted);
            CREATE TABLE IF NOT EXISTS operations(id TEXT PRIMARY KEY, owner TEXT, amount INTEGER NOT NULL CHECK(amount>=0), state TEXT NOT NULL CHECK(state IN ('reserved','submitted','spent','released')));
            CREATE TABLE IF NOT EXISTS budget_periods(id TEXT PRIMARY KEY, ceiling INTEGER NOT NULL CHECK(ceiling>0), reserved INTEGER NOT NULL DEFAULT 0, reason TEXT NOT NULL, activated REAL NOT NULL, active INTEGER NOT NULL CHECK(active IN (0,1)));
            CREATE UNIQUE INDEX IF NOT EXISTS one_active_period ON budget_periods(active) WHERE active=1;
            CREATE TABLE IF NOT EXISTS period_owner_ledger(period TEXT NOT NULL REFERENCES budget_periods(id), owner TEXT NOT NULL, reserved INTEGER NOT NULL, ceiling INTEGER NOT NULL, PRIMARY KEY(period,owner));
            CREATE TABLE IF NOT EXISTS period_operations(id TEXT PRIMARY KEY, period TEXT NOT NULL REFERENCES budget_periods(id), owner TEXT, amount INTEGER NOT NULL CHECK(amount>=0), state TEXT NOT NULL CHECK(state IN ('reserved','submitted','spent','released')));
            CREATE TABLE IF NOT EXISTS guard(id INTEGER PRIMARY KEY CHECK(id=1), busy INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS manual_provider_credit(id TEXT PRIMARY KEY, account TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>=0), recorded REAL NOT NULL, expires REAL NOT NULL, evidence TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS manual_provider_debits(operation TEXT PRIMARY KEY, snapshot TEXT NOT NULL REFERENCES manual_provider_credit(id), amount INTEGER NOT NULL CHECK(amount>=0));
            CREATE TABLE IF NOT EXISTS payment_quotes(id TEXT PRIMARY KEY, owner TEXT NOT NULL, session TEXT NOT NULL, digest TEXT NOT NULL, amount INTEGER NOT NULL, expires REAL NOT NULL, action TEXT NOT NULL, used INTEGER NOT NULL CHECK(used IN (0,1)));
            CREATE TABLE IF NOT EXISTS style_tokens(owner TEXT PRIMARY KEY, balance INTEGER NOT NULL CHECK(balance>=0));
            INSERT OR IGNORE INTO guard VALUES(1,0);
            ''')
        os.chmod(p, 0o600)
        with self.tx() as db:
            if self._active(db):
                return
            db.execute('INSERT OR IGNORE INTO ledger VALUES(1,?,0)', (units(settings.lifetime_budget_usd),))
            # Historical ceilings are evidence, not current application limits.
            # Startup must never rewrite them or activate a new budget period.

    @contextmanager
    def tx(self):
        db = sqlite3.connect(self.settings.db_path, timeout=5)
        db.row_factory = sqlite3.Row
        try:
            db.execute('BEGIN IMMEDIATE')
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()

    def _active(self, db):
        return db.execute('SELECT * FROM budget_periods WHERE active=1').fetchone()

    def activate_budget_period(self, period_id, ceiling, reason):
        """Operator-only explicit grant. Never called by startup or an HTTP route."""
        amount = units(ceiling)
        if not isinstance(period_id, str) or not period_id.strip() or not isinstance(reason, str) or not reason.strip() or amount <= 0:
            raise ValueError('invalid_budget_period')
        with self.tx() as db:
            prior = db.execute('SELECT * FROM budget_periods WHERE id=?', (period_id,)).fetchone()
            if prior:
                if prior['ceiling'] != amount or prior['reason'] != reason:
                    raise ValueError('budget_period_conflict')
                return  # Archived IDs are tombstones, not a reactivation request.
            if db.execute('SELECT busy FROM guard').fetchone()[0]:
                raise RuntimeError('busy_or_ambiguous')
            for table in ('operations', 'period_operations'):
                if db.execute(f"SELECT 1 FROM {table} WHERE state IN ('reserved','submitted') LIMIT 1").fetchone():
                    raise RuntimeError('unresolved_operations')
            db.execute('UPDATE budget_periods SET active=0 WHERE active=1')
            db.execute('INSERT INTO budget_periods VALUES(?,?,0,?,?,1)', (period_id, amount, reason, time.time()))

    def costs(self):
        with self.tx() as db:
            active = self._active(db)
            r = active if active else db.execute('SELECT * FROM ledger').fetchone()
            if active:
                spent = db.execute("SELECT COALESCE(sum(amount),0) FROM period_operations WHERE period=? AND state='spent'", (active['id'],)).fetchone()[0]
            else:
                spent = db.execute("SELECT COALESCE(sum(amount),0) FROM operations WHERE state='spent'").fetchone()[0]
            return {'reserved_usd': r['reserved']/1000000, 'lifetime_budget_usd': r['ceiling']/1000000,
                    # Completed estimates, NOT provider-confirmed billed amounts.
                    # Unknown legacy reservations remain pending, never refunded.
                    'spent_usd': spent/1000000, 'pending_usd': (r['reserved']-spent)/1000000,
                    'remaining_usd': max(0, r['ceiling']-r['reserved'])/1000000}

    def capacity(self, db, extra=0):
        import time
        from fastapi import HTTPException
        # Tombstones and ledger survive expiry, preventing resurrection/retry.
        expired = [r[0] for r in db.execute('SELECT id FROM jobs WHERE expires<?',(time.time(),))]
        for jid in expired:
            db.execute(
                "UPDATE jobs SET original=NULL, result=CASE WHEN state='pending' "
                "AND request_id LIKE 'tryon:%' THEN result ELSE NULL END WHERE id=?",
                (jid,),
            )
            db.execute('UPDATE claims SET image=NULL WHERE job=?',(jid,))
        used = db.execute('SELECT COALESCE(sum(COALESCE(length(original),0)+COALESCE(length(result),0)),0) FROM jobs').fetchone()[0]
        used += db.execute('SELECT COALESCE(sum(length(image)),0) FROM claims').fetchone()[0]
        if used + extra > self.settings.max_storage_bytes:
            raise HTTPException(507,'storage_limit')

    def reserve(self, db, amount, owner=None, *, enforce_budget=True):
        from fastapi import HTTPException
        if db.execute('SELECT busy FROM guard').fetchone()[0]:
            raise HTTPException(409, 'busy_or_ambiguous')
        active = self._active(db)
        r = active if active else db.execute('SELECT * FROM ledger').fetchone()
        ledger = 'budget_periods' if active else 'ledger'
        ledger_where = 'id=?' if active else 'id=1'
        period_args = (active['id'],) if active else ()
        owner_table = 'period_owner_ledger' if active else 'owner_ledger'
        owner_where = 'owner=? AND period=?' if active else 'owner=?'
        owner_args = (owner,) + period_args
        if enforce_budget and r['reserved'] + amount > r['ceiling']:
            raise HTTPException(402, 'budget_exceeded')
        if owner is not None:
            ceiling = r['ceiling'] if active else min(units(self.settings.owner_lifetime_budget_usd), r['ceiling'])
            if active:
                db.execute('INSERT OR IGNORE INTO period_owner_ledger VALUES(?,?,0,?)', (active['id'], owner, ceiling))
            else:
                db.execute('INSERT OR IGNORE INTO owner_ledger VALUES(?,0,?)', (owner, ceiling))
            if enforce_budget:
                db.execute(f'UPDATE {owner_table} SET ceiling=min(ceiling,?) WHERE {owner_where}', (ceiling,) + owner_args)
            personal = db.execute(f'SELECT * FROM {owner_table} WHERE {owner_where}', owner_args).fetchone()
            if enforce_budget and personal['reserved'] + amount > personal['ceiling']:
                raise HTTPException(402, 'owner_budget_exceeded')
            now = time.time()
            cutoff = now - self.settings.owner_rate_window_seconds
            count = db.execute('SELECT count(*) FROM owner_rate WHERE owner=? AND admitted>?', (owner, cutoff)).fetchone()[0]
            if count >= self.settings.owner_rate_limit:
                raise HTTPException(429, 'owner_rate_limited')
            db.execute('DELETE FROM owner_rate WHERE owner=? AND admitted<=?', (owner, cutoff))
            db.execute('INSERT INTO owner_rate VALUES(?,?)', (owner, now))
            db.execute(f'UPDATE {owner_table} SET reserved=reserved+? WHERE {owner_where}', (amount,) + owner_args)
        db.execute(f'UPDATE {ledger} SET reserved=reserved+? WHERE {ledger_where}', (amount,) + period_args)
        db.execute('UPDATE guard SET busy=1')

    def record_operation(self, db, operation, amount, owner=None):
        # Called in the same admission transaction as reserve and job/claim.
        if db.execute('SELECT 1 FROM operations WHERE id=? UNION ALL SELECT 1 FROM period_operations WHERE id=?', (operation, operation)).fetchone():
            raise RuntimeError('operation_already_exists')
        active = self._active(db)
        if active:
            db.execute('INSERT INTO period_operations VALUES(?,?,?,?,?)', (operation, active['id'], owner, amount, 'reserved'))
        else:
            db.execute('INSERT INTO operations VALUES(?,?,?,?)', (operation, owner, amount, 'reserved'))

    def _operation_table(self, db, operation):
        return 'period_operations' if db.execute('SELECT 1 FROM period_operations WHERE id=?', (operation,)).fetchone() else 'operations'

    def record_manual_credit(self, snapshot_id, account, amount, evidence):
        """Operator-only user Billing statement, not API-verified credit or a grant."""
        amount = units(amount)
        if not snapshot_id or not isinstance(account, str) or not account or not evidence:
            raise ValueError('invalid_manual_credit')
        with self.tx() as db:
            prior = db.execute('SELECT * FROM manual_provider_credit WHERE id=?', (snapshot_id,)).fetchone()
            if prior:
                if (prior['account'], prior['amount'], prior['evidence']) != (account, amount, evidence):
                    raise ValueError('manual_credit_conflict')
                return
            if db.execute('SELECT busy FROM guard').fetchone()[0]:
                raise RuntimeError('busy_or_ambiguous')
            now = time.time()
            db.execute('INSERT INTO manual_provider_credit VALUES(?,?,?,?,?,?)',
                       (snapshot_id, account, amount, now, now + 86400, evidence))

    def _manual_credit(self, db, account):
        row = db.execute('SELECT * FROM manual_provider_credit ORDER BY recorded DESC, rowid DESC LIMIT 1').fetchone()
        if not row or row['account'] != account or not row['recorded'] <= time.time() < row['expires']:
            return None
        debited = db.execute('SELECT COALESCE(sum(amount),0) FROM manual_provider_debits WHERE snapshot=?', (row['id'],)).fetchone()[0]
        return {'snapshot_id': row['id'], 'account': row['account'], 'recorded_at': row['recorded'],
                'expires_at': row['expires'], 'source': 'manual_non_realtime',
                'available_usd': max(0, row['amount'] - debited)/1000000, 'overspend_risk': True}

    def manual_credit(self, account):
        with self.tx() as db:
            return self._manual_credit(db, account)

    def grant_admin_tokens(self, owner):
        with self.tx() as db:
            db.execute('INSERT OR IGNORE INTO style_tokens VALUES(?,5)', (owner,))

    def style_balance(self, owner):
        with self.tx() as db:
            row = db.execute('SELECT balance FROM style_tokens WHERE owner=?', (owner,)).fetchone()
            return row['balance'] if row else 0

    def mark_submitted(self, operation, *, manual_credit_id=None):
        # Durable BEFORE the POST; persistence failure prevents submission.
        with self.tx() as db:
            table = self._operation_table(db, operation)
            if manual_credit_id is not None:
                snapshot = db.execute('SELECT * FROM manual_provider_credit WHERE id=?', (manual_credit_id,)).fetchone()
                credit = self._manual_credit(db, snapshot['account']) if snapshot else None
                row = db.execute(f'SELECT * FROM {table} WHERE id=?', (operation,)).fetchone()
                if (not credit or credit['snapshot_id'] != manual_credit_id or not row or row['state'] != 'reserved'
                        or units(credit['available_usd']) < row['amount']):
                    raise RuntimeError('manual_credit_unavailable')
                db.execute('INSERT INTO manual_provider_debits VALUES(?,?,?)', (operation, manual_credit_id, row['amount']))
            changed = db.execute(f"UPDATE {table} SET state='submitted' WHERE id=? AND state='reserved'", (operation,)).rowcount
            if changed != 1:
                raise RuntimeError('operation_not_reserved')
            owner = db.execute(f'SELECT owner FROM {table} WHERE id=?', (operation,)).fetchone()['owner']
            if owner and owner.startswith('google:'):
                debit = db.execute('UPDATE style_tokens SET balance=balance-1 WHERE owner=? AND balance>0', (owner,))
                if debit.rowcount != 1:
                    from fastapi import HTTPException
                    raise HTTPException(402, 'style_tokens_empty')

    def finish_operation(self, operation, *, success):
        with self.tx() as db:
            table = self._operation_table(db, operation)
            row = db.execute(f'SELECT * FROM {table} WHERE id=?', (operation,)).fetchone()
            if not row or row['state'] in ('released', 'spent'):
                return
            if success:
                db.execute(f"UPDATE {table} SET state='spent' WHERE id=?", (operation,))
            elif row['state'] == 'reserved':
                # Refund the originating period, never whichever is active now.
                if table == 'period_operations':
                    db.execute('UPDATE budget_periods SET reserved=reserved-? WHERE id=?', (row['amount'], row['period']))
                    if row['owner'] is not None:
                        db.execute('UPDATE period_owner_ledger SET reserved=reserved-? WHERE period=? AND owner=?', (row['amount'], row['period'], row['owner']))
                else:
                    db.execute('UPDATE ledger SET reserved=reserved-?', (row['amount'],))
                    if row['owner'] is not None:
                        db.execute('UPDATE owner_ledger SET reserved=reserved-? WHERE owner=?', (row['amount'], row['owner']))
                db.execute(f"UPDATE {table} SET state='released' WHERE id=?", (operation,))
            # submitted failures/timeouts stay pending: billing is ambiguous.

    def release(self):
        with self.tx() as db:
            db.execute('UPDATE guard SET busy=0')
