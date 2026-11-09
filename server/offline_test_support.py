"""Explicit offline owner/credit/quote fixtures for non-admission regressions.

Only tests import this module. No provider transport is contacted by login or
credit. PaidFixtureClient obtains real server quotes; it never bypasses the
production admission path. Security/quote tests use raw TestClient instead.
"""
from dataclasses import asdict, is_dataclass
from unittest.mock import patch
from fastapi.testclient import TestClient
import app as api
from test_oauth import CONFIG, HEADERS, login


def offline_app(settings, provider):
    values = asdict(settings) if is_dataclass(settings) else dict(settings)
    values = CONFIG | values
    for key, value in CONFIG.items():
        if not values.get(key):
            values[key] = value
    # Synthetic credit is explicit test data, NOT a real balance assertion.
    provider.credit_available_usd = lambda action: 100.0
    return api.create_app(values, provider)


class PaidFixtureClient(TestClient):
    def __init__(self, app, **kwargs):
        super().__init__(app, base_url='https://testserver', **kwargs)
        self.headers.update(HEADERS)
        class Patcher:
            def setattr(self, target, name, value):
                patcher = patch.object(target, name, value)
                patcher.start()
                self.patcher = patcher
        patcher = Patcher()
        try:
            assert login(self, patcher).status_code == 303
        finally:
            patcher.patcher.stop()

    def post(self, url, **kwargs):
        payload = kwargs.get('json')
        if (url in ('/api/detect', '/api/generate') and isinstance(payload, dict)
                and payload.get('confirmed') is True and not payload.get('quote_id')):
            action = url.rsplit('/', 1)[-1]
            inputs = {k: v for k, v in payload.items() if k not in ('confirmed', 'max_total_usd', 'quote_id')}
            quoted = super().post('/api/quote', json={'action': action, 'inputs': inputs})
            if quoted.status_code != 200:
                return quoted
            q = quoted.json()
            if payload.get('max_total_usd', 0) >= q['estimated_cost_usd']:
                kwargs['json'] = dict(payload, quote_id=q['quote_id'], max_total_usd=q['estimated_cost_usd'])
        return super().post(url, **kwargs)
