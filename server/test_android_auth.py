"""Offline Android login contract. No Google or inference requests."""
import pytest
from fastapi.testclient import TestClient
import app as api


@pytest.fixture
def case(tmp_path, monkeypatch):
    monkeypatch.setenv('STYLEMUSE_GOOGLE_CLIENT_ID', 'web.apps.googleusercontent.com')
    monkeypatch.setenv('STYLEMUSE_GOOGLE_ANDROID_CLIENT_IDS', 'android.apps.googleusercontent.com')
    from google.oauth2 import id_token
    claims = dict(sub='android-user', email='fixture@example.invalid', email_verified=True,
                  aud='web.apps.googleusercontent.com', azp='android.apps.googleusercontent.com')
    calls = []
    def verify(token, request, audience):
        calls.append((token, audience))
        if token == 'invalid':
            raise ValueError('invalid signature')
        return claims.copy()
    monkeypatch.setattr(id_token, 'verify_oauth2_token', verify)
    c = TestClient(api.create_app(dict(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'))), base_url='https://testserver')
    c.headers['Origin'] = 'https://yasinaday.github.io'
    c.post('/api/session')
    return c, claims, calls


def test_android_verifies_server_audience_without_web_nonce(case):
    c, claims, calls = case
    r = c.post('/api/auth/google/android', json={'credential': 'signed-id-token'})
    assert r.status_code == 200, r.text
    assert calls == [('signed-id-token', 'web.apps.googleusercontent.com')]
    assert c.post('/api/account').json()['user']['id'] == 'android-user'
    assert 'credential' not in r.json()


def test_android_unconfigured_fails_before_google_network(case, monkeypatch):
    c, _, calls = case
    monkeypatch.delenv('STYLEMUSE_GOOGLE_ANDROID_CLIENT_IDS')
    r = c.post('/api/auth/google/android', json={'credential':'signed'})
    assert r.status_code == 503
    assert calls == []


@pytest.mark.parametrize('mutation', [{'azp':'evil'}, {'azp':None}, {'email_verified':False}, {'sub':''}, {'email':''}])
def test_android_rejects_invalid_claims(case, mutation):
    c, claims, _ = case
    claims.update(mutation)
    assert c.post('/api/auth/google/android', json={'credential':'signed'}).status_code == 401
    assert c.post('/api/account').json()['user'] is None


def test_android_requires_signature_and_origin_and_valid_session(case):
    c, _, _ = case
    assert c.post('/api/auth/google/android', json={'credential':'invalid'}).status_code == 401
    assert c.post('/api/auth/google/android', json={'credential':'signed'}, headers={'Origin':'https://evil.invalid'}).status_code == 403
    c.cookies.clear()
    assert c.post('/api/auth/google/android', json={'credential':'signed'}).status_code == 401


def test_web_still_requires_original_nonce(case):
    c, claims, _ = case
    assert c.post('/api/auth/google', json={'credential':'signed'}).status_code == 401
    claims['nonce'] = c.post('/api/account').json()['nonce']
    assert c.post('/api/auth/google', json={'credential':'signed'}).status_code == 200


def test_tryon_recovery_matches_original_request_only(case, tmp_path):
    import sqlite3, json, time
    c, _, _ = case
    c.post('/api/auth/google/android', json={'credential':'signed'})
    with sqlite3.connect(tmp_path/'db') as db:
        for owner, jid, rid in [('google:android-user','tryon-j','original'),('google:other','tryon-secret','private')]:
            db.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?)',
                (jid,owner,'tryon:'+rid,'hash','pending',None,json.dumps({'request_id':'provider'}),time.time()-60))
    r = c.post('/api/operations/recover', json={'action':'tryon','request_id':'original'})
    assert r.status_code == 200, r.text
    assert r.json() == {'state':'pending','job_id':'tryon-j'}
    assert c.post('/api/operations/recover', json={'action':'tryon','request_id':'private'}).status_code == 404


def test_recovery_is_read_only_owner_bound_and_returns_completed_extraction(case, tmp_path):
    import sqlite3, json, time
    c, _, _ = case
    assert c.post('/api/auth/google/android', json={'credential':'signed'}).status_code == 200
    with sqlite3.connect(tmp_path/'db') as db:
        item = dict(id='i', preview='data:image/png;base64,AA==', category='top')
        db.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?)',
            ('j','google:android-user','extract1','hash','done','source',json.dumps([item]),time.time()+60))
    r = c.post('/api/operations/recover', json={'action':'detect','request_id':'extract1'})
    assert r.status_code == 200, r.text
    assert r.json()['result']['job_id'] == 'j'
    assert r.json()['state'] == 'done'
    assert c.post('/api/operations/recover', json={'action':'detect','request_id':'absent'}).status_code == 404
    with sqlite3.connect(tmp_path/'db') as db:
        db.execute('INSERT INTO claims VALUES(?,?,?,?)', ('j','i','done','enhanced'))
    r = c.post('/api/operations/recover', json={'action':'generate','job_id':'j','item_ids':['i']})
    assert r.status_code == 200, r.text
    assert r.json() == {'state':'done','result':{'items':[{'id':'i','image':'enhanced'}]}}
    r = c.post('/api/operations/recover', json={'action':'generate','job_id':'j','item_ids':['missing']})
    assert r.json()['state'] == 'ambiguous'
