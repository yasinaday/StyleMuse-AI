"""Portable offline regression runner; imports application only in isolated child.

Run with pytest normally. The child clears configuration before importing app and
blocks sockets; no production store, credentials, or provider can be used.
"""
import os
from pathlib import Path
import subprocess
import sys


def test_isolated_enhancement_tokens(tmp_path):
    env = {k: v for k, v in os.environ.items()
           if not k.startswith('STYLEMUSE_') and k not in ('FAL_KEY', 'REPLICATE_API_TOKEN')}
    env.update(STYLEMUSE_ENABLED='false', STYLEMUSE_DB_PATH=str(tmp_path/'import.db'),
               STYLEMUSE_STORAGE_DIR=str(tmp_path/'import-images'), TOKEN_TEST_CHILD='1')
    result = subprocess.run([sys.executable, '-m', 'pytest', str(Path(__file__).resolve()), '-v'],
                            env=env, capture_output=True, text=True, timeout=90)
    assert result.returncode == 0, result.stdout + result.stderr


if os.environ.get('TOKEN_TEST_CHILD') == '1':
    import inspect
    import socket
    import sqlite3
    import threading
    from concurrent.futures import ThreadPoolExecutor
    import pytest

    def deny(*args, **kwargs):
        raise AssertionError('REAL NETWORK DENIED')

    socket.socket.connect = deny
    socket.socket.connect_ex = deny
    socket.create_connection = deny
    from fastapi.testclient import TestClient
    from fastapi import HTTPException
    import app as api
    from test_api import image
    from store import Store

    # Do not recursively launch another child.
    del test_isolated_enhancement_tokens

    class Provider:
        def __init__(self):
            self.calls = []
            self.check = lambda: None

        def detect(self, raw):
            self.calls.append('detect')
            return [dict(category='shirt', preview=image(), prompt='shirt') for _ in range(2)]

        def generate(self, *args):
            self.check()
            self.calls.append('generate')
            return image()

        def tryon_submit(self, *args, before_submit):
            before_submit()
            self.calls.append('tryon')
            return 'offline'

    @pytest.fixture(params=['google', 'github'])
    def case(tmp_path, request):
        provider = Provider()
        settings = dict(enabled=True, db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'))
        client = TestClient(api.create_app(settings, provider), base_url='https://testserver')
        client.headers.update({'Origin': 'https://yasinaday.github.io'})
        assert client.post('/api/session').status_code == 200
        endpoint = next(r.endpoint for r in client.app.routes if r.path == '/api/account')
        auth = inspect.getclosurevars(endpoint).nonlocals['authorized']
        auth[client.cookies.get('__Host-stylemuse_session')] = dict(provider=request.param, id='fixture', login='fixture', email='fixture@example.invalid', admin=False)
        owner = request.param + ':fixture'
        with sqlite3.connect(tmp_path/'db') as db:
            db.execute('INSERT INTO style_tokens VALUES(?,20)', (owner,))
        yield client, provider, tmp_path/'db', owner
        client.close()

    def balance(case):
        with sqlite3.connect(case[2]) as db:
            row = db.execute('SELECT balance FROM style_tokens WHERE owner=?', (case[3],)).fetchone()
            return row[0] if row else None

    def quote(case, action, inputs):
        response = case[0].post('/api/quote', json=dict(action=action, inputs=inputs))
        assert response.status_code == 200, response.text
        return response.json()

    def submit(case, action, inputs, q, **extra):
        return case[0].post('/api/'+action, json=dict(inputs, quote_id=q['quote_id'], confirmed=True, max_total_usd=q['estimated_cost_usd'], **extra))

    def source(case):
        inputs = dict(image=image(), request_id='source')
        response = submit(case, 'detect', inputs, quote(case, 'detect', inputs))
        assert response.status_code == 200, response.text
        return response.json()

    @pytest.mark.parametrize('count', [1, 2])
    def test_generate_debit_before_provider_and_cache(case, count):
        job = source(case)
        before = balance(case)
        inputs = dict(job_id=job['job_id'], item_ids=[i['id'] for i in job['items'][:count]])
        q = quote(case, 'generate', inputs)
        assert q['style_tokens'] == 2*count
        observations = []
        def check():
            observations.append(balance(case))
            assert balance(case) == before-2*len(observations)
            with sqlite3.connect(case[2]) as db:
                assert db.execute("SELECT count(*) FROM operations WHERE state='submitted' AND id LIKE 'generate:%'").fetchone()[0] == 1
        case[1].check = check
        response = submit(case, 'generate', inputs, q, approved_style_tokens=2*count)
        assert response.status_code == 200, response.text
        assert balance(case) == before-2*count
        assert case[1].calls.count('generate') == count
        assert submit(case, 'generate', inputs, q, approved_style_tokens=2*count).status_code == 403
        cached = quote(case, 'generate', inputs)
        assert cached['style_tokens'] == 0
        assert submit(case, 'generate', inputs, cached, approved_style_tokens=0).status_code == 200
        assert balance(case) == before-2*count
        assert case[1].calls.count('generate') == count

    @pytest.mark.parametrize('mode', ['missing', 'wrong', 'low', 'no_row'])
    def test_reject_before_admission(case, mode):
        job = source(case)
        inputs = dict(job_id=job['job_id'], item_ids=[i['id'] for i in job['items']])
        q = quote(case, 'generate', inputs)
        with sqlite3.connect(case[2]) as db:
            if mode == 'low':
                db.execute('UPDATE style_tokens SET balance=3')
            if mode == 'no_row':
                db.execute('DELETE FROM style_tokens')
        before = balance(case)
        extra = {} if mode == 'missing' else dict(approved_style_tokens=2 if mode == 'wrong' else 4)
        response = submit(case, 'generate', inputs, q, **extra)
        assert response.status_code == (403 if mode in ('missing', 'wrong') else 402), response.text
        assert 'generate' not in case[1].calls
        assert balance(case) == before
        with sqlite3.connect(case[2]) as db:
            assert db.execute('SELECT count(*) FROM claims').fetchone()[0] == 0
            assert db.execute("SELECT count(*) FROM operations WHERE id LIKE 'generate:%'").fetchone()[0] == 0
            assert db.execute('SELECT used FROM payment_quotes WHERE id=?', (q['quote_id'],)).fetchone()[0] == 0

    def test_legacy_detect_tryon_policy_unchanged(case):
        source(case)
        after_detect = 19 if case[3].startswith('google:') else 20
        assert balance(case) == after_detect
        inputs = dict(person_image=image(), clothing_image=image(), request_id='try')
        q = quote(case, 'tryon', inputs)
        assert q['style_tokens'] == 1
        assert submit(case, 'tryon', inputs, q).status_code == 200
        assert balance(case) == after_detect-(1 if case[3].startswith('google:') else 0)

    def test_racing_duplicate_requests(case):
        job = source(case)
        before = balance(case)
        inputs = dict(job_id=job['job_id'], item_ids=[job['items'][0]['id']])
        quotes = [quote(case, 'generate', inputs) for _ in range(2)]
        gate = threading.Barrier(2)
        def run(q):
            gate.wait(timeout=5)
            return submit(case, 'generate', inputs, q, approved_style_tokens=2).status_code
        with ThreadPoolExecutor(2) as pool:
            statuses = list(pool.map(run, quotes))
        assert sorted(statuses) in ([200, 403], [200, 409]), statuses
        assert case[1].calls.count('generate') == 1
        assert balance(case) == before-2

    @pytest.mark.parametrize('period', [False, True])
    def test_atomic_submission_rollback_and_duplicate(case, period):
        store = Store(api.Settings(db_path=str(case[2]), storage_dir=str(case[2].parent/'images')))
        if period:
            store.activate_budget_period('test', 1, 'offline')
        table = 'period_operations' if period else 'operations'
        with store.tx() as db:
            store.record_operation(db, 'generate:atomic:item', 1000, case[3])
            db.execute('UPDATE style_tokens SET balance=1')
        with pytest.raises(HTTPException) as exc:
            store.mark_submitted('generate:atomic:item', style_tokens=2)
        assert exc.value.status_code == 402
        with store.tx() as db:
            assert db.execute(f'SELECT state FROM {table}').fetchone()[0] == 'reserved'
            db.execute('UPDATE style_tokens SET balance=2')
        store.mark_submitted('generate:atomic:item', style_tokens=2)
        assert balance(case) == 0
        with pytest.raises(RuntimeError, match='operation_not_reserved'):
            store.mark_submitted('generate:atomic:item', style_tokens=2)
        assert balance(case) == 0

    @pytest.mark.parametrize('available', [1, 2])
    def test_real_provider_post_observes_committed_debit(case, available):
        import httpx
        from providers import RealProviders, ProviderError
        store = Store(api.Settings(db_path=str(case[2]), storage_dir=str(case[2].parent/'images')))
        with store.tx() as db:
            store.record_operation(db, 'generate:real:item', 1000, case[3])
            db.execute('UPDATE style_tokens SET balance=?', (available,))
        seen = []
        def transport(request):
            seen.append(request.method)
            assert balance(case) == 0
            with store.tx() as db:
                assert db.execute("SELECT state FROM operations WHERE id='generate:real:item'").fetchone()[0] == 'submitted'
            return httpx.Response(403, json={})
        provider = RealProviders('', 'offline-fixture', transport=httpx.MockTransport(transport))
        try:
            with pytest.raises((HTTPException, ProviderError)):
                provider.generate(image(), {'category': 'top'}, before_submit=lambda: store.mark_submitted('generate:real:item', style_tokens=2))
            assert seen == ([] if available == 1 else ['POST'])
            assert balance(case) == (1 if available == 1 else 0)
        finally:
            provider.close()

    def test_network_denied():
        with pytest.raises(AssertionError, match='REAL NETWORK DENIED'):
            socket.create_connection(('example.invalid', 443))
