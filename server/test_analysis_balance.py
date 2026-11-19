"""Offline Google account / detection balance contract."""
import sqlite3

import pytest
from fastapi.testclient import TestClient
from google.oauth2 import id_token

import app as api
from test_api import image
from test_paid_quotes import FundedProvider


@pytest.mark.parametrize('balance,credit,expected', [
    (0, 10, 'style_tokens_empty'),
    (0, None, 'style_tokens_empty'),
    (1, 10, None),
    (516, 10, None),
    (516, None, 'provider_credit_unavailable'),
    (516, 0, 'provider_credit_insufficient'),
])
def test_analysis_balance(tmp_path, monkeypatch, balance, credit, expected):
    audience = 'web.apps.googleusercontent.com'
    android = 'android.apps.googleusercontent.com'
    monkeypatch.setenv('STYLEMUSE_GOOGLE_CLIENT_ID', audience)
    monkeypatch.setenv('STYLEMUSE_GOOGLE_ANDROID_CLIENT_IDS', android)
    monkeypatch.setattr(id_token, 'verify_oauth2_token', lambda *_: dict(
        sub='analysis-user', email='fixture@example.invalid', email_verified=True,
        aud=audience, azp=android))
    provider = FundedProvider()
    provider.balance = credit
    path = tmp_path / 'db'
    c = TestClient(api.create_app(dict(enabled=True, db_path=str(path),
        storage_dir=str(tmp_path/'images')), provider), base_url='https://testserver')
    c.headers['Origin'] = 'https://yasinaday.github.io'
    assert c.post('/api/session').status_code == 200
    assert c.post('/api/auth/google/android', json={'credential':'fixture'}).status_code == 200
    with sqlite3.connect(path) as db:
        db.execute('INSERT INTO style_tokens VALUES(?,?)', ('google:analysis-user', balance))
        db.execute('INSERT INTO style_tokens VALUES(?,?)', ('google:other-user', 999))
    assert c.post('/api/account').json()['balance'] == balance
    inputs = dict(image=image(), request_id='analysis-balance')
    quote = c.post('/api/quote', json=dict(action='detect', inputs=inputs))
    if expected:
        assert quote.status_code == 402, quote.text
        assert quote.json()['error'] == expected
        assert c.post('/api/account').json()['balance'] == balance
        assert provider.detect_calls == 0
        with sqlite3.connect(path) as db:
            assert db.execute('SELECT count(*) FROM payment_quotes').fetchone()[0] == 0
        return
    assert quote.status_code == 200, quote.text
    assert quote.json()['style_tokens'] == 1
    result = c.post('/api/detect', json=dict(inputs, confirmed=True,
        max_total_usd=quote.json()['estimated_cost_usd'], quote_id=quote.json()['quote_id']))
    assert result.status_code == 200, result.text
    assert provider.detect_calls == 1
    assert c.post('/api/account').json()['balance'] == balance - 1
    with sqlite3.connect(path) as db:
        assert db.execute("SELECT balance FROM style_tokens WHERE owner='google:other-user'").fetchone()[0] == 999
