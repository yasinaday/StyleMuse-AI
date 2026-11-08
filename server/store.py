"""SQLite writer-serialized admission and durable private job storage."""
import sqlite3
import os
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
            CREATE TABLE IF NOT EXISTS guard(id INTEGER PRIMARY KEY CHECK(id=1), busy INTEGER NOT NULL);
            INSERT OR IGNORE INTO guard VALUES(1,0);
            ''')
        os.chmod(p, 0o600)
        with self.tx() as db:
            db.execute('INSERT OR IGNORE INTO ledger VALUES(1,?,0)', (units(settings.lifetime_budget_usd),))
            db.execute('UPDATE ledger SET ceiling=min(ceiling,?)', (units(settings.lifetime_budget_usd),))

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
            return {'reserved_usd': r['reserved']/1000000, 'lifetime_budget_usd': r['ceiling']/1000000}

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

    def reserve(self, db, amount):
        from fastapi import HTTPException
        if db.execute('SELECT busy FROM guard').fetchone()[0]:
            raise HTTPException(409, 'busy_or_ambiguous')
        r = db.execute('SELECT * FROM ledger').fetchone()
        if r['reserved'] + amount > r['ceiling']:
            raise HTTPException(402, 'budget_exceeded')
        db.execute('UPDATE ledger SET reserved=reserved+?', (amount,))
        db.execute('UPDATE guard SET busy=1')

    def release(self):
        with self.tx() as db:
            db.execute('UPDATE guard SET busy=0')
