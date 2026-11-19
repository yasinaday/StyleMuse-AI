from test_paid_quotes import client
from test_virtual_tryon import TryFixture
from test_api import image
from test_oauth import HEADERS


def test_sequence_single_consent_and_recovery(tmp_path, monkeypatch):
    c, p = client(tmp_path, monkeypatch, TryFixture())
    def post(path, body):
        return c.post('/api/' + path, headers=HEADERS, json=body)
    inputs = dict(person_image=image(), garments=[image(), image()], garment_ids=['top', 'bottom'], request_id='outfit')
    q = post('quote', dict(action='tryon_sequence', inputs=inputs))
    assert q.status_code == 200, q.text
    assert q.json()['style_tokens'] == 2
    consent = dict(inputs, quote_id=q.json()['quote_id'], confirmed=True, max_total_usd=.08)
    assert post('tryon/sequence', dict(consent, garments=[image()], garment_ids=['top'])).status_code == 403
    assert post('tryon/sequence', dict(consent, garment_ids=['bottom', 'top'])).status_code == 403
    assert post('tryon/sequence', consent).json()['state'] == 'ready'
    assert post('tryon/sequence', consent).status_code == 403
    key = {'request_id': 'outfit'}
    assert post('tryon/sequence/status', key).json()['completed'] == 0
    assert p.calls == 0
    assert post('tryon/sequence/advance', dict(key, step=1)).status_code == 409
    for step in range(2):
        assert post('tryon/sequence/advance', dict(key, step=step)).json()['state'] == 'pending'
        assert post('tryon/sequence/advance', dict(key, step=step)).status_code == 409
        result = post('tryon/sequence/status', key).json()
        assert result['completed'] == step + 1
        assert result['image'] == 'https://fal.media/fixture.png'
    assert result['state'] == 'done'
    assert post('tryon/sequence/status', key).json() == result
    assert p.calls == 2
