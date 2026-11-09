"""Offline adapter contract tests, NOT real inference. No credentials/network."""
import base64
import io
import json
import unittest
from pathlib import Path
import httpx
from PIL import Image
try:
    import providers as p
except ModuleNotFoundError:
    import types
    p = types.SimpleNamespace()


def png(size=(12, 16), color='red'):
    out = io.BytesIO()
    Image.new('RGB', size, color).save(out, 'PNG')
    return out.getvalue()


def uri(raw):
    return 'data:image/png;base64,' + base64.b64encode(raw).decode()


class SafetyTests(unittest.TestCase):
    def test_transport_allowlist_redirect_size_and_auth(self):
        self.assertTrue(hasattr(p, 'SafeHTTP'), 'missing bounded provider transport')
        seen = []
        def handler(req):
            seen.append(req)
            if req.url.path == '/redirect':
                return httpx.Response(302, headers={'location': 'https://evil.example/'})
            return httpx.Response(200, content=b'12345')
        http = p.SafeHTTP(transport=httpx.MockTransport(handler), max_bytes=4)
        for bad in ['http://replicate.delivery/a', 'https://replicate.delivery.evil/a',
                    'https://u@replicate.delivery/a', 'https://127.0.0.1/a',
                    'https://replicate.delivery:8443/a']:
            with self.assertRaises(p.ProviderError):
                http.request('GET', bad)
        self.assertEqual(len(seen), 0)
        with self.assertRaises(p.ProviderError):
            http.request('GET', 'https://replicate.delivery/a')
        self.assertNotIn('authorization', seen[-1].headers)
        with self.assertRaises(p.ProviderError):
            http.request('GET', 'https://api.replicate.com/redirect', token='secret')
        self.assertEqual(seen[-1].headers['authorization'], 'Bearer secret')
        self.assertEqual(len(seen), 2)
        with self.assertRaises(p.ProviderError):
            http.request('GET', 'https://replicate.delivery/a', token='secret')


class MaskTests(unittest.TestCase):
    def test_real_retained_masks_are_cropped_transparent_without_shoes(self):
        self.assertTrue(hasattr(p, 'extract_items'), 'missing real mask extraction')
        root = Path('/opt/stylemuse-ai')
        if not (root / 'test-photo.jpg').exists():
            self.skipTest('external private fixtures unavailable')
        photo = Image.open(root / 'test-photo.jpg').convert('RGB')
        results = [json.loads((root / f'approved-four-test/results-{i}.json').read_text()) for i in range(4)]
        items = p.extract_items(photo, results)
        self.assertEqual({i['category'] for i in items}, {'jacket', 'jumpsuit', 'bag'})
        self.assertEqual(len(items), 3)
        for item in items:
            im = Image.open(io.BytesIO(base64.b64decode(item['preview'].split(',')[1])))
            self.assertEqual(im.mode, 'RGBA')
            self.assertLess(im.width * im.height, photo.width * photo.height)
            self.assertEqual(im.getchannel('A').getextrema(), (0, 255))
            self.assertIn('TRYOFF', item['prompt'])
            self.assertNotIn('burgundy', item['prompt'])
        with self.assertRaises(p.ProviderError):
            p.extract_items(photo, [{'input': {'text': 'top'}, 'masks': [[[[1]]]], 'scores': [0.9]}])


class DetectTests(unittest.TestCase):
    def test_schema_verified_before_single_submit_then_bounded_poll(self):
        self.assertTrue(hasattr(p, 'RealProviders'), 'missing Replicate adapter')
        schema = json.loads(Path('/opt/stylemuse-ai/model-schema-current.json').read_text())
        seen = []
        result = {'input': {'text': 'jacket'}, 'scores': [.9], 'masks': [[[[0, 0, 0], [0, 1, 1], [0, 1, 0]]]]}
        def handler(req):
            seen.append(req)
            if '/versions/' in req.url.path:
                return httpx.Response(200, json=schema)
            if req.method == 'POST':
                self.assertEqual(req.headers['cancel-after'], '40s')
                payload = json.loads(req.content)
                self.assertEqual(payload['version'], p.SAM_VERSION)
                self.assertEqual([json.loads(x)['text'] for x in payload['input']['prompts']], list(p.CATEGORIES))
                return httpx.Response(201, json={'id': 'abc', 'status': 'starting'})
            if req.url.host == 'api.replicate.com':
                return httpx.Response(200, json={'status': 'succeeded', 'output': {'results': ['https://replicate.delivery/result.json']}})
            self.assertNotIn('authorization', req.headers)
            return httpx.Response(200, json=result)
        adapter = p.RealProviders('rep-secret', 'fal-secret', transport=httpx.MockTransport(handler), sleep=lambda _: None)
        items = adapter.detect(png((3, 3)))
        self.assertEqual(items[0]['category'], 'jacket')
        self.assertEqual(sum(r.method == 'POST' for r in seen), 1)
        self.assertIn('/versions/', seen[0].url.path)
        seen.clear()
        schema['id'] = 'wrong'
        with self.assertRaises(p.ProviderError):
            adapter.detect(png((3, 3)))
        self.assertFalse(any(r.method == 'POST' for r in seen))


class GenerateTests(unittest.TestCase):
    def test_original_photo_exact_runner_fields_single_png(self):
        self.assertTrue(hasattr(getattr(p, 'RealProviders', object), 'generate'), 'missing fal adapter')
        seen = []
        original = uri(png())
        def handler(req):
            seen.append(req)
            if req.method == 'POST':
                body = json.loads(req.content)
                self.assertEqual(str(req.url), 'https://queue.fal.run/' + p.FAL_MODEL)
                self.assertEqual(body, {'prompt': p.tryoff_prompt('jacket'), 'image_urls': [original],
                    'loras': [{'path': p.LORA, 'scale': 1.0}], 'image_size': {'width': 768, 'height': 1024},
                    'num_images': 1, 'num_inference_steps': 28, 'guidance_scale': 5, 'seed': 42,
                    'acceleration': 'none', 'enable_safety_checker': True, 'output_format': 'png', 'sync_mode': False})
                return httpx.Response(200, json={'request_id': 'abc', 'status_url': 'https://queue.fal.run/fal-ai/flux-2-klein/requests/abc/status', 'response_url': 'https://queue.fal.run/fal-ai/flux-2-klein/requests/abc', 'cancel_url': 'https://queue.fal.run/fal-ai/flux-2-klein/requests/abc/cancel'})
            if req.url.path.endswith('/status'):
                return httpx.Response(200, json={'status': 'COMPLETED'})
            if req.url.host == 'queue.fal.run':
                return httpx.Response(200, json={'images': [{'url': 'https://v3.fal.media/output.png'}]})
            self.assertNotIn('authorization', req.headers)
            return httpx.Response(200, content=png((768, 1024)))
        adapter = p.RealProviders('rep', 'fal', transport=httpx.MockTransport(handler))
        output = adapter.generate(original, {'category': 'jacket', 'prompt': p.tryoff_prompt('jacket'), 'preview': uri(png(color='blue'))})
        self.assertTrue(output.startswith('data:image/png;base64,'))
        self.assertEqual(sum(r.method == 'POST' for r in seen), 1)


class LifecycleTests(unittest.TestCase):
    def test_poll_exhaustion_cancels_once_for_both_providers(self):
        schema = json.loads(Path('/opt/stylemuse-ai/model-schema-current.json').read_text())
        for provider in ('replicate', 'fal'):
            with self.subTest(provider=provider):
                seen = []
                def handler(req):
                    seen.append(req)
                    if '/versions/' in req.url.path:
                        return httpx.Response(200, json=schema)
                    if req.url.path.endswith('/cancel'):
                        return httpx.Response(200, json={})
                    if req.method == 'POST' and req.url.host == 'api.replicate.com':
                        return httpx.Response(200, json={'id': 'abc'})
                    if req.method == 'POST':
                        return httpx.Response(200, json={'request_id': 'abc', 'status_url': 'https://queue.fal.run/fal-ai/flux-2-klein/requests/abc/status', 'response_url': 'https://queue.fal.run/fal-ai/flux-2-klein/requests/abc'})
                    return httpx.Response(200, json={'status': 'processing' if provider == 'replicate' else 'IN_QUEUE'})
                adapter = p.RealProviders('r', 'f', transport=httpx.MockTransport(handler), sleep=lambda _: None, max_polls=2)
                with self.assertRaises(p.ProviderError):
                    if provider == 'replicate':
                        adapter.detect(png())
                    else:
                        adapter.generate(uri(png()), {'category': 'top'})
                cancels = [r for r in seen if r.url.path.endswith('/cancel')]
                self.assertEqual(len(cancels), 1, 'timeout must cancel exactly once')
                self.assertEqual(cancels[0].method, 'POST' if provider == 'replicate' else 'PUT')
                self.assertEqual(sum(r.method == 'POST' and not r.url.path.endswith('/cancel') for r in seen), 1)


class BoundaryTests(unittest.TestCase):
    def test_original_above_one_megapixel_rejected_before_network(self):
        seen = []
        def handler(req):
            seen.append(req)
            return httpx.Response(500)
        adapter = p.RealProviders('r', 'f', transport=httpx.MockTransport(handler))
        with self.assertRaises(p.ProviderError):
            adapter.detect(png((1025, 1024)))
        self.assertEqual(seen, [], 'oversize original must fail before schema GET or POST')


class TelemetryTests(unittest.TestCase):
    def test_env_bootstrap_inert_and_sanitized_events(self):
        self.assertTrue(hasattr(p.RealProviders, 'from_env'), 'missing inert environment bootstrap')
        from unittest.mock import patch
        events, seen = [], []
        schema = json.loads(Path('/opt/stylemuse-ai/model-schema-current.json').read_text())
        def handler(req):
            seen.append(req)
            if '/versions/' in req.url.path:
                return httpx.Response(200, json=schema)
            if req.method == 'POST':
                return httpx.Response(200, json={'id': 'abc', 'status': 'starting', 'logs': 'secret logs'})
            return httpx.Response(200, json={'id': 'abc', 'status': 'succeeded', 'metrics': {'predict_time': 2.5, 'unsafe': 'r-secret'}, 'output': {'results': []}})
        with patch.dict('os.environ', {'REPLICATE_API_TOKEN': 'r-secret', 'FAL_KEY': 'f-secret'}):
            adapter = p.RealProviders.from_env(transport=httpx.MockTransport(handler), event_callback=events.append)
        self.assertEqual(seen, [])
        self.assertEqual(adapter.detect(uri(png())), [])
        self.assertEqual(events[0], {'provider': 'replicate', 'id': 'abc', 'status': 'starting', 'metrics': {}})
        self.assertEqual(events[-1]['metrics'], {'predict_time': 2.5})
        self.assertNotIn('secret', json.dumps(events))


if __name__ == '__main__':
    unittest.main()
