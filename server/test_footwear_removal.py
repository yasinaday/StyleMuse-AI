"""Offline footwear exclusion boundaries; no real provider transport."""
import json
import sqlite3

import httpx
import pytest
from PIL import Image

import providers as p
from test_api import setup, detect, image

FOOTWEAR = ('shoes', 'Shoes', 'Left-shoe', 'Right-shoe', 'footwear', 'shoe',
            'left_shoe', 'right shoe', 'sneakers', 'pink sneakers', 'boots',
            'sandals', 'heels', 'trainers', 'loafers', 'slippers', 'flip-flops')


def test_fal_rejects_footwear_before_transport_or_submission():
    seen, submitted = [], []
    adapter = p.RealProviders('r', 'f', transport=httpx.MockTransport(
        lambda req: seen.append(req) or httpx.Response(500)))
    try:
        for category in FOOTWEAR:
            with pytest.raises(p.ProviderError):
                adapter.generate(image(), {'category': category}, before_submit=lambda: submitted.append(True))
        assert seen == []
        assert submitted == []
    finally:
        adapter.close()


def test_extraction_discards_footwear_before_masks_preserving_other_garments():
    photo = Image.new('RGB', (3, 3), 'red')
    top = {'input': {'text': 'top'}, 'scores': [.9],
           'masks': [[[0, 0, 0], [0, 1, 1], [0, 1, 0]]]}
    # Unsupported output must not require usable masks or poison a mixed photo.
    results = [{'input': {'text': category}} for category in FOOTWEAR]
    items = p.extract_items(photo, results + [top])
    assert [item['category'] for item in items] == ['top']
    assert items == p.extract_items(photo, [top])
    assert p.extract_items(photo, results) == []


def test_sam_prompt_allowlist_excludes_footwear():
    assert not any(p.is_footwear(category) for category in p.CATEGORIES)
    assert {'top', 'trousers', 'jacket', 'jumpsuit', 'bag'} <= set(p.CATEGORIES)


def test_api_filters_mixed_and_only_footwear_detection_and_replay(tmp_path):
    client, provider, _ = setup(tmp_path, enabled=True, lifetime_budget_usd=1)
    provider.detect = lambda _: ([{'category': category} for category in FOOTWEAR] +
                                 [dict(category='top', preview=image(), prompt='top')])
    response = detect(client)
    assert response.status_code == 200
    assert [item['category'] for item in response.json()['items']] == ['top']
    assert detect(client).json() == response.json()
    provider.detect = lambda _: [{'category': category} for category in FOOTWEAR]
    empty = client.post('/api/detect', json=dict(image=image(), request_id='only-shoes', confirmed=True, max_total_usd=1))
    assert empty.status_code == 200
    assert empty.json()['items'] == []


@pytest.mark.parametrize('category', FOOTWEAR)
def test_legacy_footwear_hidden_and_unclaimable_before_budget(tmp_path, category):
    client, provider, settings = setup(tmp_path, enabled=True, lifetime_budget_usd=1)
    job = detect(client).json()
    shoe = dict(id='legacy-shoe', category=category, preview=image(), prompt='legacy')
    with sqlite3.connect(settings['db_path']) as db:
        row = db.execute('SELECT result FROM jobs WHERE id=?', (job['job_id'],)).fetchone()
        items = json.loads(row[0]) + [shoe]
        db.execute('UPDATE jobs SET result=? WHERE id=?', (json.dumps(items), job['job_id']))
    before = client.post('/api/health').json()
    replay = detect(client)
    assert replay.status_code == 200
    assert replay.json() == job
    for ids in ([shoe['id']], [job['items'][0]['id'], shoe['id']]):
        response = client.post('/api/generate', json=dict(job_id=job['job_id'], item_ids=ids,
                                                        confirmed=True, max_total_usd=1))
        assert response.status_code == 404
    assert provider.generate_calls == 0
    assert client.post('/api/health').json() == before
    with sqlite3.connect(settings['db_path']) as db:
        assert db.execute('SELECT count(*) FROM claims').fetchone()[0] == 0
    good = client.post('/api/generate', json=dict(job_id=job['job_id'], item_ids=[job['items'][0]['id']],
                                                confirmed=True, max_total_usd=1))
    assert good.status_code == 200
    assert provider.generate_calls == 1
