"""Free fixtures only: never contact a provider."""
import sqlite3
import pytest
from test_paid_quotes import client, FundedProvider
from test_api import image
from test_oauth import HEADERS

class TryFixture(FundedProvider):
    calls = 0
    def tryon_submit(self, person, clothing, *, before_submit):
        before_submit()
        self.calls += 1
        return 'fixture-request'
    def tryon_poll(self, rid):
        assert rid == 'fixture-request'
        return 'https://fal.media/fixture.png'

def inputs():
    return dict(person_image=image(), clothing_image=image(), request_id='try-fixture')

def test_tryon_job_cannot_be_reused_as_detection_job(tmp_path, monkeypatch):
    c,p,jid=submitted(tmp_path, monkeypatch)
    assert c.post('/api/tryon/status',headers=HEADERS,json=dict(job_id=jid)).json()['state']=='done'
    data=dict(job_id=jid,item_ids=['fake'])
    assert c.post('/api/quote',headers=HEADERS,json=dict(action='generate',inputs=data)).status_code==404
    assert c.post('/api/generate',headers=HEADERS,json=dict(data,confirmed=True,max_total_usd=.1)).status_code==404

def test_single_use_quote_async_result_and_replay(tmp_path, monkeypatch):
    p = TryFixture()
    c, _ = client(tmp_path, monkeypatch, p)
    data = inputs()
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='tryon', inputs=data))
    assert q.status_code == 200, q.text
    assert q.json()['estimated_cost_usd'] == .04
    approved = dict(data, quote_id=q.json()['quote_id'], confirmed=True, max_total_usd=.04)
    response = c.post('/api/tryon', headers=HEADERS, json=approved)
    assert response.status_code == 200, response.text
    jid = response.json()['job_id']
    assert response.json()['state'] == 'pending'
    assert c.post('/api/tryon', headers=HEADERS, json=approved).status_code == 403
    result = c.post('/api/tryon/status', headers=HEADERS, json={'job_id':jid})
    assert result.json()['image'] == 'https://fal.media/fixture.png'
    assert c.post('/api/tryon/status', headers=HEADERS, json={'job_id':jid}).json() == result.json()
    assert p.calls == 1
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT busy FROM guard').fetchone()[0] == 0
        assert db.execute("SELECT state FROM operations WHERE id=?", ('tryon:'+jid,)).fetchone()[0] == 'spent'


def submitted(tmp_path, monkeypatch, p=None):
    p = p or TryFixture()
    c, _ = client(tmp_path, monkeypatch, p)
    data = inputs()
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='tryon', inputs=data)).json()
    response = c.post('/api/tryon', headers=HEADERS, json=dict(data, quote_id=q['quote_id'], confirmed=True, max_total_usd=.04))
    assert response.status_code == 200
    return c, p, response.json()['job_id']

def test_concurrent_completion_cannot_release_a_new_operation_guard(tmp_path, monkeypatch):
    c, p, jid = submitted(tmp_path, monkeypatch)
    nested = False
    def poll(rid):
        nonlocal nested
        if not nested:
            nested = True
            assert c.post('/api/tryon/status', headers=HEADERS, json={'job_id':jid}).status_code == 200
            with sqlite3.connect(tmp_path/'db') as db:
                db.execute('UPDATE guard SET busy=1')  # another operation admitted
        return 'https://fal.media/fixture.png'
    p.tryon_poll = poll
    assert c.post('/api/tryon/status', headers=HEADERS, json={'job_id':jid}).status_code == 200
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT busy FROM guard').fetchone()[0] == 1

def test_failed_provider_job_is_terminal_without_refunding_ambiguous_charge(tmp_path, monkeypatch):
    from virtual_tryon import TryOnError
    c, p, jid = submitted(tmp_path, monkeypatch)
    def poll(rid): raise TryOnError('generation_failed')
    p.tryon_poll = poll
    assert c.post('/api/tryon/status', headers=HEADERS, json={'job_id':jid}).json()['state'] == 'failed'
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT busy FROM guard').fetchone()[0] == 0
        assert db.execute('SELECT state FROM jobs WHERE id=?',(jid,)).fetchone()[0] == 'failed'
        assert db.execute('SELECT state FROM operations WHERE id=?',('tryon:'+jid,)).fetchone()[0] == 'submitted'


@pytest.mark.parametrize('mutation', ['person','clothing','amount','consent','quote','expired','balance','origin'])
def test_tampering_and_credit_recheck_make_no_submission(tmp_path, monkeypatch, mutation):
    p = TryFixture()
    c, _ = client(tmp_path, monkeypatch, p)
    data = inputs()
    q = c.post('/api/quote', headers=HEADERS, json=dict(action='tryon', inputs=data)).json()
    approved = dict(data, quote_id=q['quote_id'], confirmed=True, max_total_usd=.04)
    headers = dict(HEADERS)
    import base64
    changed = 'data:image/png;base64,' + base64.b64encode(base64.b64decode(image().split(',')[1]) + b'fixture').decode()
    if mutation == 'person': approved['person_image'] = changed
    if mutation == 'clothing': approved['clothing_image'] = changed
    if mutation == 'amount': approved['max_total_usd'] = .0399999
    if mutation == 'consent': approved['confirmed'] = False
    if mutation == 'quote': approved['quote_id'] = 'fake'
    if mutation == 'expired':
        with sqlite3.connect(tmp_path/'db') as db: db.execute('UPDATE payment_quotes SET expires=0')
    if mutation == 'balance': p.balance = .039
    if mutation == 'origin': headers['Origin'] = 'https://evil.invalid'
    result = c.post('/api/tryon', headers=headers, json=approved)
    assert result.status_code in (402,403), result.text
    assert p.calls == 0
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT count(*) FROM operations').fetchone()[0] == 0

@pytest.mark.parametrize('bad', ['https://localhost/x','https://example.com/image.png','data:image/png;base64,AAAA'])
def test_external_or_invalid_images_never_admitted(tmp_path, monkeypatch, bad):
    c,p = client(tmp_path, monkeypatch, TryFixture())
    data=inputs();data['person_image']=bad
    assert c.post('/api/quote', headers=HEADERS, json=dict(action='tryon',inputs=data)).status_code == 422
    assert p.calls == 0

def test_anonymous_session_and_no_session_cannot_quote_or_submit(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient
    c,p=client(tmp_path, monkeypatch, TryFixture())
    anon=TestClient(c.app,base_url='https://testserver')
    for path, body in [('/api/quote',dict(action='tryon', inputs=inputs())),('/api/tryon', inputs()),('/api/tryon/status',dict(job_id='unknown'))]:
        assert anon.post(path,headers=HEADERS,json=body).status_code == 401
    anon.post('/api/session',headers=HEADERS,json={})
    for path, body in [('/api/quote',dict(action='tryon', inputs=inputs())),('/api/tryon', inputs()),('/api/tryon/status',dict(job_id='unknown'))]:
        assert anon.post(path,headers=HEADERS,json=body).status_code == 403
    assert p.calls == 0

def test_poll_pending_then_transient_error_then_resume_never_resubmits(tmp_path, monkeypatch):
    c,p,jid=submitted(tmp_path, monkeypatch)
    p.tryon_poll=lambda rid: None
    assert c.post('/api/tryon/status',headers=HEADERS,json=dict(job_id=jid)).json()['state']=='pending'
    def broken(rid): raise RuntimeError('fixture GET timeout')
    p.tryon_poll=broken
    assert c.post('/api/tryon/status',headers=HEADERS,json=dict(job_id=jid)).status_code==502
    p.tryon_poll=lambda rid:'https://fal.media/fixture.png'
    assert c.post('/api/tryon/status',headers=HEADERS,json=dict(job_id=jid)).json()['state']=='done'
    assert p.calls == 1

def test_known_failed_job_has_durable_terminal_status(tmp_path, monkeypatch):
    from virtual_tryon import TryOnError
    c,p,jid=submitted(tmp_path, monkeypatch)
    def failed(rid): raise TryOnError('generation_failed')
    p.tryon_poll=failed
    for _ in range(2):
        response=c.post('/api/tryon/status',headers=HEADERS,json=dict(job_id=jid))
        assert response.status_code==200
        assert response.json()['state']=='failed'


def test_pending_lookup_recovers_same_job_without_paid_submit(tmp_path, monkeypatch):
    c, provider, job = submitted(tmp_path, monkeypatch)
    assert c.post('/api/tryon/pending', headers=HEADERS).json() == {'job_id': job}
    assert c.post('/api/tryon/status', headers=HEADERS, json={'job_id': job}).json()['state'] == 'done'
    assert c.post('/api/tryon/pending', headers=HEADERS).status_code == 404
    assert provider.calls == 1
