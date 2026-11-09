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
            CREATE TABLE IF NOT EXISTS guard(id INTEGER PRIMARY KEY CHECK(id=1), busy INTEGER NOT NULL);
            INSERT OR IGNORE INTO guard VALUES(1,0);
            ''')
        os.chmod(p, 0o600)
        with self.tx() as db:
            db.execute('INSERT OR IGNORE INTO ledger VALUES(1,?,0)', (units(settings.lifetime_budget_usd),))
            db.execute('UPDATE ledger SET ceiling=min(ceiling,?)', (units(settings.lifetime_budget_usd),))
            global_ceiling = db.execute('SELECT ceiling FROM ledger').fetchone()[0]
            db.execute('UPDATE owner_ledger SET ceiling=min(ceiling,?)',
                       (min(units(settings.owner_lifetime_budget_usd), global_ceiling),))

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

    def costs(self):
        with self.tx() as db:
            r = db.execute('SELECT * FROM ledger').fetchone()
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
            db.execute('UPDATE jobs SET original=NULL,result=NULL WHERE id=?',(jid,))
            db.execute('UPDATE claims SET image=NULL WHERE job=?',(jid,))
        used = db.execute('SELECT COALESCE(sum(COALESCE(length(original),0)+COALESCE(length(result),0)),0) FROM jobs').fetchone()[0]
        used += db.execute('SELECT COALESCE(sum(length(image)),0) FROM claims').fetchone()[0]
        if used + extra > self.settings.max_storage_bytes:
            raise HTTPException(507,'storage_limit')

    def reserve(self, db, amount, owner=None):
        from fastapi import HTTPException
        if db.execute('SELECT busy FROM guard').fetchone()[0]:
            raise HTTPException(409, 'busy_or_ambiguous')
        r = db.execute('SELECT * FROM ledger').fetchone()
        if r['reserved'] + amount > r['ceiling']:
            raise HTTPException(402, 'budget_exceeded')
        if owner is not None:
            ceiling = min(units(self.settings.owner_lifetime_budget_usd), r['ceiling'])
            db.execute('INSERT OR IGNORE INTO owner_ledger VALUES(?,0,?)', (owner, ceiling))
            db.execute('UPDATE owner_ledger SET ceiling=min(ceiling,?) WHERE owner=?', (ceiling, owner))
            personal = db.execute('SELECT * FROM owner_ledger WHERE owner=?', (owner,)).fetchone()
            if personal['reserved'] + amount > personal['ceiling']:
                raise HTTPException(402, 'owner_budget_exceeded')
            now = time.time()
            cutoff = now - self.settings.owner_rate_window_seconds
            count = db.execute('SELECT count(*) FROM owner_rate WHERE owner=? AND admitted>?', (owner, cutoff)).fetchone()[0]
            if count >= self.settings.owner_rate_limit:
                raise HTTPException(429, 'owner_rate_limited')
            db.execute('DELETE FROM owner_rate WHERE owner=? AND admitted<=?', (owner, cutoff))
            db.execute('INSERT INTO owner_rate VALUES(?,?)', (owner, now))
            db.execute('UPDATE owner_ledger SET reserved=reserved+? WHERE owner=?', (amount, owner))
        db.execute('UPDATE ledger SET reserved=reserved+?', (amount,))
        db.execute('UPDATE guard SET busy=1')

    def record_operation(self, db, operation, amount, owner=None):
        # Called in the same admission transaction as reserve and job/claim.
        db.execute('INSERT INTO operations VALUES(?,?,?,?)', (operation, owner, amount, 'reserved'))

    def mark_submitted(self, operation):
        # Durable BEFORE the POST; persistence failure prevents submission.
        with self.tx() as db:
            changed = db.execute("UPDATE operations SET state='submitted' WHERE id=? AND state='reserved'", (operation,)).rowcount
            if changed != 1:
                raise RuntimeError('operation_not_reserved')

    def finish_operation(self, operation, *, success):
        with self.tx() as db:
            row = db.execute('SELECT * FROM operations WHERE id=?', (operation,)).fetchone()
            if not row or row['state'] in ('released', 'spent'):
                return
            if success:
                db.execute("UPDATE operations SET state='spent' WHERE id=?", (operation,))
            elif row['state'] == 'reserved':
                # Only an unwound live invocation that never crossed the durable
                # submit boundary may refund. Never sweep these on startup.
                db.execute('UPDATE ledger SET reserved=reserved-?', (row['amount'],))
                if row['owner'] is not None:
                    db.execute('UPDATE owner_ledger SET reserved=reserved-? WHERE owner=?', (row['amount'], row['owner']))
                db.execute("UPDATE operations SET state='released' WHERE id=?", (operation,))
            # submitted failures/timeouts stay pending: billing is ambiguous.

    def release(self):
        with self.tx() as db:
            db.execute('UPDATE guard SET busy=0')
