"""Offline admin contract; isolation is established BEFORE importing app."""
import os
import tempfile
from pathlib import Path
_ISOLATION = tempfile.TemporaryDirectory(prefix='stylemuse-admin-', dir=os.environ['TMPDIR'])
os.environ.update(STYLEMUSE_ENABLED='false', STYLEMUSE_DB_PATH=str(Path(_ISOLATION.name)/'import.sqlite'), STYLEMUSE_STORAGE_DIR=str(Path(_ISOLATION.name)/'images'))
import json
import sqlite3
import time
import pytest
from test_android_auth import case


def test_admin_summary_requires_verified_admin(case):
    c, claims, _ = case
    assert c.post('/api/admin/overview', json={}).status_code == 403
    c.post('/api/auth/google/android', json={'credential':'signed'})
    assert c.post('/api/admin/overview', json={}).status_code == 403
    c.post('/api/auth/logout')
    c.post('/api/session')
    claims['email'] = 'adysoft2000@gmail.com'
    c.post('/api/auth/google/android', json={'credential':'signed'})
    r = c.post('/api/admin/overview', json={})
    assert r.status_code == 200, r.text
    assert r.json()['settings']['inference_enabled'] is False
    assert c.post('/api/admin/overview', json={}, headers={'Origin':'https://evil.invalid'}).status_code == 403


def test_admin_safe_details_never_expose_payloads_or_secrets(case, tmp_path):
    c, claims, _ = case
    claims['email'] = 'adysoft2000@gmail.com'
    c.post('/api/auth/google/android', json={'credential':'signed'})
    with sqlite3.connect(tmp_path/'db') as db:
        db.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?)', ('job1','google:android-user','rid','hash','done','SECRET-IMAGE',json.dumps([dict(id='blouse', category='top', preview='SECRET-IMAGE', prompt='SECRET-PROMPT')]),time.time()+60))
        db.execute('INSERT INTO claims VALUES(?,?,?,?)', ('job1','blouse','done','SECRET-ENHANCED'))
    r = c.post('/api/admin/overview', json={})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body['jobs'][0]['id'] == 'job1'
    assert body['jobs'][0]['items'][0]['id'] == 'blouse'
    assert body['jobs'][0]['items'][0]['enhancement_state'] == 'done'
    assert 'SECRET' not in r.text
    assert {'token_balances','token_load_history','operations','errors','settings'} <= body.keys()
    assert c.post('/api/auth/logout').status_code == 200
    assert c.post('/api/admin/overview', json={}).status_code == 403


@pytest.mark.parametrize('picture', ['https://lh3.googleusercontent.com/photo', 'https://evil.invalid/private', 'http://lh3.googleusercontent.com/photo', 'https://lh3.googleusercontent.com@evil.invalid/photo'])
def test_profile_verified_claims_safe_picture_and_logout(case, picture):
    c, claims, _ = case
    claims.update(name='Profile Name', picture=picture)
    response=c.post('/api/auth/google/android',json={'credential':'signed'})
    assert response.status_code == 200
    user=response.json()['user']
    assert user['name']=='Profile Name' and user['admin'] is False
    assert user.get('picture') == (picture if picture.startswith('https://lh3.googleusercontent.com/') else None)
    assert c.post('/api/account').json()['user']==user
    assert c.post('/api/auth/logout').status_code == 200
    c.post('/api/session')
    assert c.post('/api/account').json()['user'] is None
