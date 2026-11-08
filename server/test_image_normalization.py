"""Offline upload normalization regressions; never contact a provider."""
import base64
import sqlite3
from io import BytesIO
from pathlib import Path

import pytest
from PIL import Image, ImageOps
from fastapi.testclient import TestClient

import app as api
from providers import original_image, extract_items, png_uri


def decode(uri):
    return Image.open(BytesIO(base64.b64decode(uri.split(',', 1)[1])))


@pytest.mark.parametrize('source', ['real', 'oversized', 'exif'])
def test_upload_normalized_before_detection_storage_and_generation(tmp_path, source):
    if source == 'real':
        import os
        path = Path(os.getenv('STYLEMUSE_TEST_PHOTO', '/opt/stylemuse-ai/test-photo.jpg'))
        if not path.is_file():
            pytest.skip('Set STYLEMUSE_TEST_PHOTO to an authorized private sample; sample is not published')
        raw = path.read_bytes()
    else:
        photo = Image.new('RGB', (4000, 4000) if source == 'oversized' else (4000, 3000), 'navy')
        photo.paste('red', (0, 0, 2000, 1500))
        out = BytesIO()
        exif = Image.Exif()
        if source == 'exif':
            exif[274] = 6
        photo.save(out, 'JPEG', exif=exif)
        raw = out.getvalue()
    with Image.open(BytesIO(raw)) as photo:
        expected = ImageOps.exif_transpose(photo).convert('RGB')
    original_size = expected.size
    received = []

    class OfflineProvider:
        def detect(self, uri):
            photo = original_image(uri)  # Exercise the actual provider size guard.
            received.append(uri)
            assert photo.width * photo.height <= 1_048_576
            assert abs(photo.width / photo.height - original_size[0] / original_size[1]) < .005
            reference = expected.resize(photo.size)
            for xy in [(photo.width // 4, photo.height // 4), (3 * photo.width // 4, 3 * photo.height // 4)]:
                assert max(abs(a-b) for a, b in zip(photo.getpixel(xy), reference.getpixel(xy))) < 8
            # Full-frame mask coordinates must match the normalized photo.
            row = [0] * photo.width
            mask = [row] * photo.height
            mask[1] = [0, 1, 1] + [0] * (photo.width - 3)
            mask[2] = [0, 1] + [0] * (photo.width - 2)
            return extract_items(photo, [{'input': {'text': 'top'}, 'scores': [.9], 'masks': [mask]}])

        def generate(self, uri, item):
            assert uri == received[0]
            return png_uri(Image.new('RGB', (768, 1024), 'white'))

    settings = api.Settings(access_token='offline', enabled=True, lifetime_budget_usd=1,
        db_path=str(tmp_path/'state.sqlite'), storage_dir=str(tmp_path/'images'))
    with TestClient(api.create_app(settings, OfflineProvider())) as client:
        client.headers['Authorization'] = 'Bearer offline'
        response = client.post('/api/detect', json={'image': 'data:image/jpeg;base64,' + base64.b64encode(raw).decode(),
            'request_id': source, 'confirmed': True, 'max_total_usd': 1})
        assert response.status_code == 200, response.text
        job = response.json()
        with sqlite3.connect(settings.db_path) as db:
            stored = db.execute('SELECT original FROM jobs WHERE id=?', (job['job_id'],)).fetchone()[0]
        assert stored == received[0]
        assert decode(stored).getexif().get(274) is None
        preview = decode(job['items'][0]['preview'])
        assert preview.size == (2, 2)
        assert preview.getchannel('A').getextrema() == (0, 255)
        result = client.post('/api/generate', json={'job_id': job['job_id'],
            'item_ids': [job['items'][0]['id']], 'confirmed': True, 'max_total_usd': 1})
        assert result.status_code == 200, result.text
        assert decode(result.json()['items'][0]['image']).size == (768, 1024)
