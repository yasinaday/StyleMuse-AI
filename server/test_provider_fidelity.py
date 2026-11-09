"""Offline synthetic regressions: geometry is not semantic classification."""
import base64
import io
import os
import tempfile
from pathlib import Path
import unittest

# Set isolation before any optional app import, never touch the service database.
_ISOLATION = tempfile.TemporaryDirectory(prefix='stylemuse-fidelity-', dir=os.environ.get('TMPDIR', '/root/.hermes/cache/scratch'))
os.environ['STYLEMUSE_ENABLED'] = 'false'
os.environ['STYLEMUSE_DB_PATH'] = str(Path(_ISOLATION.name) / 'test.sqlite3')
os.environ['STYLEMUSE_STORAGE_DIR'] = str(Path(_ISOLATION.name) / 'storage')

from PIL import Image
from providers import ProviderError, extract_items, tryoff_prompt


def detection(category, score=.9, points=None):
    points = points if points is not None else {(2, 2), (2, 3), (3, 3)}
    return {'input': {'text': category}, 'scores': [score],
            'masks': [[[int((x, y) in points) for x in range(12)] for y in range(16)]]}


class FidelityTests(unittest.TestCase):
    def test_small_and_boundary_masks_report_review_not_success(self):
        item = extract_items(Image.new('RGB', (12, 16)),
                             [detection('bag', points={(0, 0), (0, 1), (1, 1)})])[0]
        self.assertEqual(item['mask_quality']['status'], 'review_required')
        self.assertIn('small_mask', item['quality_warnings'])
        self.assertIn('image_boundary_contact', item['quality_warnings'])
        self.assertFalse(item['category_verified'])

    def test_api_diagnostics_are_bounded_and_legacy_results_are_honest(self):
        import app as api
        legacy = api.quality_fields({})
        self.assertEqual(legacy['mask_quality'], {'status': 'missing', 'source': 'unavailable'})
        self.assertFalse(legacy['category_verified'])
        for bad in ({'category_verified': True}, {'quality_warnings': ['secret']},
                    {'quality_warnings': ['small_mask'] * 6},
                    {'mask_quality': {'status': 'perfect', 'source': 'detector_mask'}},
                    {'mask_quality': {'status': 'unverified', 'source': 'detector_mask', 'detector_score': float('nan')}},
                    {'mask_quality': {'status': 'unverified', 'source': 'detector_mask', 'bbox': [1] * 100}}):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                api.quality_fields(bad)

    def test_api_preserves_quality_report_and_durable_replay(self):
        from fastapi.testclient import TestClient
        import app as api
        photo = Image.new('RGB', (12, 16), (13, 29, 71))
        item = extract_items(photo, [detection('trousers')])[0]
        class OfflineProvider:
            def detect(self, original):
                return [dict(item, secret_payload='must not leak')]
        with tempfile.TemporaryDirectory(dir=_ISOLATION.name) as root:
            client = TestClient(api.create_app(dict(access_token='offline-test', enabled=True,
                lifetime_budget_usd=1, db_path=str(Path(root)/'api.sqlite'),
                storage_dir=str(Path(root)/'images')), OfflineProvider()))
            client.headers['Authorization'] = 'Bearer offline-test'
            from providers import png_uri
            payload = dict(image=png_uri(photo), confirmed=True, request_id='quality-report', max_total_usd=1)
            response = client.post('/api/detect', json=payload)
            self.assertEqual(response.status_code, 200, response.text)
            public = response.json()['items'][0]
            for key in ('mask_quality', 'category_verified', 'quality_warnings'):
                self.assertIn(key, public)
                self.assertEqual(public[key], item[key])
            self.assertNotIn('secret_payload', public)
            self.assertEqual(client.post('/api/detect', json=payload).json(), response.json())

    def test_prompt_only_reconstructs_missing_regions_without_redesign(self):
        for category in ('jacket', 'trousers', 'bag'):
            prompt = tryoff_prompt(category)
            for phrase in ('fabric pattern', 'buttons', 'visible accessories',
                           'Reconstruct only missing or occluded regions', 'Do not redesign',
                           'Preserve all visible regions unchanged', 'original colors'):
                self.assertIn(phrase, prompt)

    def test_missing_or_empty_mask_is_explicitly_rejected(self):
        missing = {'input': {'text': 'trousers'}, 'scores': []}
        for row in (missing, detection('trousers', points=set())):
            with self.subTest(row=row):
                with self.assertRaisesRegex(ProviderError, 'Missing|Empty'):
                    extract_items(Image.new('RGB', (12, 16)), [row])

    def test_mask_report_is_geometry_only_not_semantic_certainty(self):
        item = extract_items(Image.new('RGB', (12, 16)),
                             [detection('pants', points={(2, 2), (2, 3), (3, 3), (3, 4)})])[0]
        self.assertFalse(item['category_verified'])
        self.assertEqual(item['mask_quality']['status'], 'unverified')
        self.assertEqual(item['mask_quality']['foreground_pixels'], 4)
        self.assertEqual(item['mask_quality']['bbox'], [2, 2, 4, 5])
        self.assertEqual(item['mask_quality']['source'], 'detector_mask')
        self.assertIn('semantic_category_unverified', item['quality_warnings'])
        self.assertIn('mask_completeness_unverified', item['quality_warnings'])

    def test_trousers_preserved_when_duplicate_shoes_are_filtered(self):
        photo = Image.new('RGB', (12, 16))
        for rows in ([detection('trousers', .99), detection('shoes', .8)],
                     [detection('shoes', .99), detection('trousers', .8)]):
            with self.subTest(rows=[r['input']['text'] for r in rows]):
                items = extract_items(photo, rows)
                self.assertEqual([i['category'] for i in items], ['trousers'])
                self.assertFalse(items[0]['category_verified'])
