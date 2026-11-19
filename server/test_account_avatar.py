"""Account-owned avatar persistence, entirely offline with synthetic identities."""
import sqlite3
import pytest
from fastapi.testclient import TestClient
import app as api
from test_android_auth import case
from test_api import image


def sign_in(c):
    assert c.post('/api/auth/google/android', json={'credential': 'signed'}).status_code == 200


def test_avatar_upload_restores_after_logout_and_server_restart(case, tmp_path):
    c, claims, _ = case
    sign_in(c)
    result = c.post('/api/account/avatar', json={'image': image()})
    assert result.status_code == 200, result.text
    saved = result.json()['user']['avatar']
    assert saved.startswith('data:image/png;base64,')
    assert c.post('/api/account').json()['user']['avatar'] == saved
    assert c.post('/api/auth/logout').status_code == 200
    restarted = TestClient(api.create_app(dict(db_path=str(tmp_path/'db'), storage_dir=str(tmp_path/'images'))), base_url='https://testserver')
    restarted.headers.update(c.headers)
    restarted.post('/api/session')
    sign_in(restarted)
    assert restarted.post('/api/account').json()['user']['avatar'] == saved
    claims['sub'] = 'different-account'
    restarted.post('/api/auth/logout')
    restarted.post('/api/session')
    sign_in(restarted)
    assert 'avatar' not in restarted.post('/api/account').json()['user']


@pytest.mark.parametrize('payload', [{'image':'https://example.invalid/photo.png'}, {'image':'data:image/png;base64,bad'}, {'image':image(), 'owner':'someone-else'}, {}])
def test_invalid_avatar_is_rejected_without_replacing_saved_photo(case, payload):
    c, _, _ = case
    sign_in(c)
    good = c.post('/api/account/avatar', json={'image':image()})
    assert good.status_code == 200
    assert c.post('/api/account/avatar', json=payload).status_code == 422
    assert c.post('/api/account').json()['user']['avatar'] == good.json()['user']['avatar']


def test_avatar_requires_google_session_and_exact_origin(case):
    c, _, _ = case
    assert c.post('/api/account/avatar', json={'image':image()}).status_code == 403
    sign_in(c)
    assert c.post('/api/account/avatar', json={'image':image()}, headers={'Origin':'https://evil.invalid'}).status_code == 403
    c.cookies.clear()
    assert c.post('/api/account/avatar', json={'image':image()}).status_code == 401


def test_avatar_upload_does_not_spend_or_create_jobs(case, tmp_path):
    c, _, _ = case
    sign_in(c)
    assert c.post('/api/account/avatar', json={'image':image()}).status_code == 200
    with sqlite3.connect(tmp_path/'db') as db:
        for table in ('jobs','operations','payment_quotes','style_tokens'):
            assert db.execute(f'SELECT count(*) FROM {table}').fetchone()[0] == 0


def test_logout_during_normalization_prevents_avatar_write(case, tmp_path, monkeypatch):
    c, _, _ = case
    sign_in(c)
    original = api.normalize
    def normalize(*args, **kwargs):
        result = original(*args, **kwargs)
        assert c.post('/api/auth/logout').status_code == 200
        return result
    monkeypatch.setattr(api, 'normalize', normalize)
    assert c.post('/api/account/avatar', json={'image':image()}).status_code == 401
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT count(*) FROM account_avatars').fetchone()[0] == 0


def test_avatar_storage_quota_replacement_is_atomic(case, monkeypatch):
    import inspect
    c, _, _ = case
    sign_in(c)
    endpoint = next(r.endpoint for r in c.app.routes if r.path == '/api/account/avatar')
    settings = inspect.getclosurevars(endpoint).nonlocals['s']
    saved = c.post('/api/account/avatar', json={'image':image()}).json()['user']['avatar']
    monkeypatch.setattr(settings, 'max_storage_bytes', len(saved))
    assert c.post('/api/account/avatar', json={'image':image()}).status_code == 200
    monkeypatch.setattr(settings, 'max_storage_bytes', 1)
    assert c.post('/api/account/avatar', json={'image':image()}).status_code == 507
    assert c.post('/api/account').json()['user']['avatar'] == saved


def test_avatar_jpeg_normalizes_to_metadata_free_png(case):
    import base64
    from io import BytesIO
    from PIL import Image
    c, _, _ = case
    sign_in(c)
    raw = BytesIO()
    exif = Image.Exif()
    exif[270] = 'private fixture description'
    Image.new('RGB', (12, 8), 'blue').save(raw, 'JPEG', exif=exif)
    result = c.post('/api/account/avatar', json={'image':'data:image/jpeg;base64,' + base64.b64encode(raw.getvalue()).decode()})
    assert result.status_code == 200
    avatar = result.json()['user']['avatar']
    assert avatar.startswith('data:image/png;base64,')
    with Image.open(BytesIO(base64.b64decode(avatar.split(',')[1]))) as photo:
        assert not photo.getexif()
