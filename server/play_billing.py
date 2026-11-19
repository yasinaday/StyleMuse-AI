"""Fail-closed Play consumables. No app import, provider calls or startup grants.

Store.tx() is the existing BEGIN IMMEDIATE transaction interface. Purchase
receipt and style_tokens credit commit together; consumption is retried after
commit. Tokens are hashed in the receipt ledger and never logged here.
"""
import hashlib
import hmac
import re
from urllib.parse import quote


def account_id(owner, secret):
    if not isinstance(owner, str) or not owner.startswith(('user:', 'google:')) or not owner.split(':', 1)[1]:
        raise ValueError('authenticated_account_required')
    return hmac.new(secret, owner.encode(), hashlib.sha256).hexdigest()


class GooglePublisher:
    """Production transport; missing ADC/permission/network errors never grant."""
    def __init__(self):
        import google.auth
        from google.auth.transport.requests import AuthorizedSession
        credentials, _ = google.auth.default(scopes=['https://www.googleapis.com/auth/androidpublisher'])
        self.session = AuthorizedSession(credentials)

    def _url(self, package, product, token):
        return ('https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'
                + quote(package, safe='') + '/purchases/products/' + quote(product, safe='')
                + '/tokens/' + quote(token, safe=''))

    def get(self, package, product, token):
        response = self.session.get(self._url(package, product, token), timeout=15)
        if response.status_code != 200:
            raise RuntimeError('play_verification_unavailable')
        return response.json()

    def consume(self, package, product, token):
        response = self.session.post(self._url(package, product, token) + ':consume', timeout=15)
        if response.status_code != 204:
            raise RuntimeError('play_consumption_unavailable')


class PlayBilling:
    def __init__(self, store, publisher, *, package, catalog, account_secret, signing_sha256):
        if (not publisher or not package or not catalog or not isinstance(account_secret, bytes)
                or len(account_secret) < 32 or not isinstance(signing_sha256, str)
                or not re.fullmatch(r'[0-9a-fA-F]{64}', signing_sha256)
                or any(not re.fullmatch(r'[a-z0-9_.]+', p) or type(n) is not int or not 0 < n <= 1000000
                       for p, n in catalog.items())):
            raise ValueError('play_not_configured')
        self.store, self.publisher = store, publisher
        self.package, self.catalog, self.secret = package, dict(catalog), account_secret
        with store.tx() as db:
            db.execute('''CREATE TABLE IF NOT EXISTS play_receipts(
                token_hash TEXT PRIMARY KEY, owner TEXT NOT NULL, package TEXT NOT NULL,
                product TEXT NOT NULL, amount INTEGER NOT NULL, consumed INTEGER NOT NULL DEFAULT 0)''')

    def configuration(self, owner):
        return {'account_id': account_id(owner, self.secret), 'product_ids': sorted(self.catalog)}

    def verify(self, owner, product, token):
        expected = account_id(owner, self.secret)
        if product not in self.catalog or not isinstance(token, str) or not 1 <= len(token) <= 8192:
            raise ValueError('invalid_play_purchase')
        digest = hashlib.sha256(token.encode()).hexdigest()
        purchase = self.publisher.get(self.package, product, token)
        if not hmac.compare_digest(str(purchase.get('obfuscatedExternalAccountId', '')), expected):
            raise ValueError('purchase_account_mismatch')
        if purchase.get('productId', product) != product or purchase.get('purchaseToken', token) != token:
            raise ValueError('purchase_identity_mismatch')
        state = purchase.get('purchaseState')
        if type(state) is not int or state not in (0, 1, 2):
            raise ValueError('invalid_purchase_state')
        if state != 0:
            return {'status': 'pending' if state == 2 else 'cancelled', 'consumed': False}
        quantity = purchase.get('quantity', 1)
        if type(quantity) is not int or quantity != 1:
            raise ValueError('unsupported_purchase_quantity')
        consumption = purchase.get('consumptionState')
        if type(consumption) is not int or consumption not in (0, 1):
            raise ValueError('invalid_consumption_state')
        with self.store.tx() as db:
            prior = db.execute('SELECT * FROM play_receipts WHERE token_hash=?', (digest,)).fetchone()
            if prior:
                if (prior['owner'], prior['package'], prior['product']) != (owner, self.package, product):
                    raise ValueError('purchase_replay_conflict')
                consumed = bool(prior['consumed'])
            else:
                if consumption != 0:
                    raise ValueError('unrecognized_consumed_purchase')
                db.execute('INSERT INTO play_receipts VALUES(?,?,?,?,?,0)',
                           (digest, owner, self.package, product, self.catalog[product]))
                db.execute('INSERT INTO style_tokens VALUES(?,?) ON CONFLICT(owner) DO UPDATE SET balance=balance+excluded.balance',
                           (owner, self.catalog[product]))
                consumed = False
        if not consumed:
            try:
                if consumption == 0:
                    self.publisher.consume(self.package, product, token)
                with self.store.tx() as db:
                    db.execute('UPDATE play_receipts SET consumed=1 WHERE token_hash=?', (digest,))
                consumed = True
            except Exception:
                # Credit is already committed. Never compensate or grant again.
                # Client must retry token verification until consumed is true.
                consumed = False
        return {'status': 'credited', 'consumed': consumed, 'balance': self.store.style_balance(owner)}
