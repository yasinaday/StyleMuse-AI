"""Offline sequence accounting: synthetic Google auth and provider only."""
import sqlite3
import pytest
from fastapi.testclient import TestClient
from google.oauth2 import id_token
import app as api
from test_api import image
from test_virtual_tryon import TryFixture

@pytest.mark.parametrize('lost_submit', [False, True])
def test_sequence_google_tokens_and_original_job_recovery(tmp_path, monkeypatch, lost_submit):
    monkeypatch.setenv('STYLEMUSE_GOOGLE_CLIENT_ID', 'web.apps.googleusercontent.com')
    monkeypatch.setenv('STYLEMUSE_GOOGLE_ANDROID_CLIENT_IDS', 'android.apps.googleusercontent.com')
    monkeypatch.setattr(id_token, 'verify_oauth2_token', lambda *_: dict(
        sub='sequence-user', email='fixture@example.invalid', email_verified=True,
        aud='web.apps.googleusercontent.com', azp='android.apps.googleusercontent.com'))
    provider = TryFixture()
    path = tmp_path/'db'
    c = TestClient(api.create_app(dict(enabled=True, db_path=str(path),
        storage_dir=str(tmp_path/'images')), provider), base_url='https://testserver')
    c.headers['Origin'] = 'https://yasinaday.github.io'
    assert c.post('/api/session').status_code == 200
    assert c.post('/api/auth/google/android', json={'credential': 'fixture'}).status_code == 200
    with sqlite3.connect(path) as db:
        db.execute('INSERT INTO style_tokens VALUES(?,2)', ('google:sequence-user',))
    def post(route, body):
        return c.post('/api/'+route, json=body)
    inputs = dict(request_id='durable', person_image=image(), garments=[image(), image()], garment_ids=['top', 'bottom'])
    q = post('quote', dict(action='tryon_sequence', inputs=inputs)).json()
    assert q['style_tokens'] == 2
    assert post('tryon/sequence', dict(inputs, confirmed=True, quote_id=q['quote_id'], max_total_usd=.08)).status_code == 200
    key = {'request_id':'durable'}
    submit = provider.tryon_submit
    if lost_submit:
        def lose(*args, **kwargs):
            submit(*args, **kwargs)
            raise TimeoutError('synthetic lost response')
        provider.tryon_submit = lose
    assert post('tryon/sequence/advance', dict(key, step=0)).status_code == (502 if lost_submit else 200)
    if lost_submit:
        for _ in range(3):
            assert post('tryon/sequence/status', key).json()['state'] == 'ambiguous'
            assert post('tryon/sequence/advance', dict(key, step=0)).status_code == 409
        assert provider.calls == 1
        assert post('account', {}).json()['balance'] == 1
        return
    for _ in range(3):
        result = post('tryon/sequence/status', key).json()
        assert result['completed'] == 1
        assert post('tryon/sequence/advance', dict(key, step=0)).status_code == 409
        assert post('account', {}).json()['balance'] == 1
    assert post('tryon/sequence/advance', dict(key, step=1)).status_code == 200
    for _ in range(3):
        assert post('tryon/sequence/status', key).json()['state'] == 'done'
        assert post('tryon/sequence/advance', dict(key, step=1)).status_code == 409
        assert post('account', {}).json()['balance'] == 0
    assert provider.calls == 2
