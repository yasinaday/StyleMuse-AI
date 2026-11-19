"""Synthetic blouse/skirt references: no paid provider transports."""
import os
import tempfile
from pathlib import Path
_ISOLATION = tempfile.TemporaryDirectory(prefix='stylemuse-enhance-', dir=os.environ['TMPDIR'])
os.environ.update(STYLEMUSE_ENABLED='false', STYLEMUSE_DB_PATH=str(Path(_ISOLATION.name)/'import.sqlite'), STYLEMUSE_STORAGE_DIR=str(Path(_ISOLATION.name)/'images'))
import io
import base64
import pytest
from PIL import Image
import providers as p


def test_blouse_skirt_references_are_isolated_original_pixels():
    original = Image.new('RGB', (12,16), 'red')
    for y in range(8,16):
        for x in range(12):
            original.putpixel((x,y), (0,0,255))
    rows = []
    for cat, lo, hi in [('top',1,7), ('skirt',9,15)]:
        rows.append({'input':{'text':cat},'scores':[.9], 'masks':[[[int(2<=x<10 and lo<=y<hi and (x+y)%5 != 0) for x in range(12)] for y in range(16)]]})
    items = p.extract_items(original, rows)
    references = []
    for item in items:
        reference = p.enhancement_reference(p.png_uri(original), item)
        references.append(reference)
        image = Image.open(io.BytesIO(base64.b64decode(reference.split(',')[1]))).convert('RGB')
        pixels = {image.getpixel((x,y)) for y in range(image.height) for x in range(image.width)}
        expected = (255,0,0) if item['category']=='top' else (0,0,255)
        assert expected in pixels
        assert pixels <= {expected, (255,255,255)}
    assert references[0] != references[1]
    item = dict(items[0], category='shoes')
    with pytest.raises(p.ProviderError):
        p.enhancement_reference(p.png_uri(original), item)


def test_real_provider_submits_matching_mask_not_full_outfit(monkeypatch):
    original = Image.new('RGB',(12,16),'red')
    item = p.extract_items(original,[{'input':{'text':'top'}, 'scores':[.9],
        'masks':[[[int(2<=x<10 and 2<=y<7 and (x+y)%5 != 0) for x in range(12)] for y in range(16)]]}])[0]
    expected = p.enhancement_reference(p.png_uri(original),item)
    adapter = p.RealProviders('fake','fake')
    seen = []
    def submit(method, url, key, body=None):
        if method == 'POST':
            seen.append(body)
            assert body['image_urls'] == [expected]
            raise p.ProviderError('offline-stop')
    monkeypatch.setattr(adapter, '_json', submit)
    with pytest.raises(p.ProviderError, match='offline-stop'):
        adapter.generate(p.png_uri(original), item)
    assert len(seen) == 1


def test_generation_audit_binds_each_item_and_sanitizes_failure(tmp_path):
    import app as api
    from offline_test_support import PaidFixtureClient, offline_app
    from test_api import image
    import sqlite3
    class Fake:
        def detect(self, original):
            return [dict(category=cat, preview=image(), prompt='fixture') for cat in ('top','skirt')]
        def generate(self, original, item):
            if item['category'] == 'skirt':
                raise RuntimeError('SECRET-provider-token')
            return image()
    client = PaidFixtureClient(offline_app(dict(enabled=True,lifetime_budget_usd=1,db_path=str(tmp_path/'db'),storage_dir=str(tmp_path/'images')),Fake()))
    job = client.post('/api/detect',json=dict(image=image(),request_id='audit-source',confirmed=True,max_total_usd=1)).json()
    response = client.post('/api/generate',json=dict(job_id=job['job_id'],item_ids=[i['id'] for i in job['items']],confirmed=True,max_total_usd=1))
    assert response.status_code == 502, response.text
    with sqlite3.connect(tmp_path/'db') as db:
        rows = db.execute('SELECT item,category,outcome,code,source_hash,reference_hash FROM inference_audit WHERE stage=\'generate\' ORDER BY rowid').fetchall()
    assert [(r[0],r[1],r[2]) for r in rows] == [(job['items'][0]['id'],'top','done'),(job['items'][1]['id'],'skirt','failed')]
    assert rows[1][3] == 'provider_failed_no_retry'
    assert all(len(r[4]) == 64 and len(r[5]) == 64 for r in rows)
    assert 'SECRET' not in str(rows)


def test_detection_failure_is_durable_safe_admin_diagnostic(tmp_path):
    from offline_test_support import PaidFixtureClient, offline_app
    from test_api import image
    import sqlite3
    class Fake:
        def detect(self, original):
            raise RuntimeError('SECRET-provider-body')
    c=PaidFixtureClient(offline_app(dict(enabled=True,lifetime_budget_usd=1,db_path=str(tmp_path/'db'),storage_dir=str(tmp_path/'images')),Fake()))
    assert c.post('/api/detect',json=dict(image=image(),request_id='failure',confirmed=True,max_total_usd=1)).status_code == 502
    with sqlite3.connect(tmp_path/'db') as db:
        rows=db.execute("SELECT stage,outcome,code FROM inference_audit").fetchall()
        state=db.execute('SELECT state FROM jobs').fetchone()[0]
    assert rows == [('detect','failed','provider_failed_no_retry')]
    assert state == 'failed'


def test_http_generation_keeps_item_identity_and_original(tmp_path, monkeypatch):
    """Exercise routing/storage with genuine synthetic masks, not paid inference."""
    import json
    import sqlite3
    from offline_test_support import PaidFixtureClient, offline_app
    original = Image.new('RGB', (12, 16), 'red')
    for y in range(8, 16):
        for x in range(12):
            original.putpixel((x, y), (0, 0, 255))
    source = p.png_uri(original)
    rows = [dict(input={'text':cat}, scores=[.9], masks=[[
        [int(2<=x<10 and lo<=y<hi and (x+y)%5!=0) for x in range(12)]
        for y in range(16)]]) for cat,lo,hi in [('top',1,7),('skirt',9,15)]]
    adapter = p.RealProviders('fixture', 'fixture')
    def detect(photo, before_submit):
        before_submit()
        return p.extract_items(p.original_image(photo), rows)
    seen = []
    def generate(photo, item, before_submit):
        before_submit()
        seen.append((item['id'], item['category'], p.enhancement_reference(photo,item)))
        return p.enhancement_reference(photo,item)
    monkeypatch.setattr(adapter, 'detect', detect)
    monkeypatch.setattr(adapter, 'generate', generate)
    c = PaidFixtureClient(offline_app(dict(enabled=True,lifetime_budget_usd=1,
        db_path=str(tmp_path/'db'),storage_dir=str(tmp_path/'images')),adapter))
    response = c.post('/api/detect',json=dict(image=source,request_id='identity',confirmed=True,max_total_usd=1))
    assert response.status_code == 200, response.text
    job = response.json()
    with sqlite3.connect(tmp_path/'db') as db:
        before = db.execute('SELECT original,result FROM jobs').fetchone()
    ids = [i['id'] for i in reversed(job['items'])]
    r = c.post('/api/generate',json=dict(job_id=job['job_id'],item_ids=ids,confirmed=True,max_total_usd=1))
    assert r.status_code == 200, r.text
    assert [i['id'] for i in r.json()['items']] == ids
    assert [i[0] for i in seen] == ids
    categories = {i['id']:i['category'] for i in job['items']}
    assert all(categories[i]==cat for i,cat,_ in seen)
    assert seen[0][2] != seen[1][2]
    with sqlite3.connect(tmp_path/'db') as db:
        assert db.execute('SELECT original,result FROM jobs').fetchone() == before
        assert db.execute('SELECT count(*) FROM inference_audit WHERE outcome=\'done\'').fetchone()[0] == 2
        # GitHub legacy detection is uncharged; each enhancement costs 2.
        assert db.execute('SELECT balance FROM style_tokens').fetchone()[0] == 96
    # Replay returns original claim image and never resubmits either item.
    r = c.post('/api/generate',json=dict(job_id=job['job_id'],item_ids=ids,confirmed=True,max_total_usd=1))
    assert r.status_code == 200 and len(seen) == 2
