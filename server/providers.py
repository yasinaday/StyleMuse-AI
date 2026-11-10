"""Real provider adapters. Construction is inert; methods can incur charges.

Call only behind the backend's explicit approval/budget/one-shot claim gate.
No submission retry, including ambiguous connection errors. Offline tests are
transport contract tests, not evidence of real inference quality or billing.
"""
import base64
import io
import json
import time
from pathlib import Path
from urllib.parse import urlsplit

import httpx
from PIL import Image, ImageChops


class ProviderError(RuntimeError):
    """Sanitized provider failure (never contains tokens or response bodies)."""


CATEGORIES = ('jacket', 'top', 'trousers', 'skirt', 'dress', 'jumpsuit', 'bag', 'hat', 'scarf', 'belt', 'sunglasses', 'jewelry')
ALIASES = {'pants': 'trousers', 'leather jacket': 'jacket', 'burgundy handbag': 'bag'}


def is_footwear(category):
    """Recognize legacy detector labels and footwear aliases at every boundary."""
    if not isinstance(category, str):
        return False
    words = category.casefold().replace('-', ' ').replace('_', ' ').split()
    return bool(set(words) & {'shoe', 'shoes', 'footwear', 'sneaker', 'sneakers',
                             'boot', 'boots', 'sandal', 'sandals', 'heel', 'heels',
                             'trainer', 'trainers', 'loafer', 'loafers', 'slipper',
                             'slippers', 'flipflop', 'flipflops'} or
                'flip flop' in ' '.join(words))


def png_uri(image):
    out = io.BytesIO()
    image.save(out, 'PNG')
    return 'data:image/png;base64,' + base64.b64encode(out.getvalue()).decode('ascii')


def tryoff_prompt(category):
    if category not in CATEGORIES:
        raise ProviderError('Unknown or unsupported garment category')
    return ('TRYOFF extract only the ' + category + ' from the reference image over a white background, '
            'product photography style. NO HUMAN VISIBLE. Preserve the original colors, material, texture, '
            'fabric pattern, cut, construction, hardware, pockets, buttons and visible accessories belonging '
            'to the target item. Preserve all visible regions unchanged. '
            'Reconstruct only missing or occluded regions, conservatively continuing the visible construction. '
            'Do not redesign, recolor, restyle, simplify patterns or replace fabric. '
            'Show the complete item without cropping; '
            'preserve the open front, zipper position, pockets and original texture exactly as visible. '
            'Do not close an open jacket or zipper. Do not invent labels, lining, pockets, '
            'accessories, branding or decoration; leave uncertain hidden details plain. '
            'Remove person, skin, hair and all unrelated clothing and accessories. '
            'No added text; preserve only markings visibly present in the reference.')


def extract_items(photo, results):
    """Full-image binary/probability masks; singleton axes only.

    Suppress a contained lower-body hypothesis only when a larger one-piece
    candidate exists. Resolve near-identical silhouettes (IoU >= .85) by score,
    not prompt order. Preserve layered masks; discard unsupported footwear.
    These geometry heuristics cannot infer a missing jumpsuit detection.
    """
    candidates = []
    for result in results:
        category = result.get('input', {}).get('text', '')
        if is_footwear(category):
            continue
        category = ALIASES.get(category, category)
        if category not in CATEGORIES:
            raise ProviderError('Unknown detector category')
        if 'masks' not in result or 'scores' not in result:
            raise ProviderError('Missing detector masks or scores')
        masks, scores = result['masks'], result['scores']
        if not isinstance(masks, list) or len(masks) != len(scores) or len(masks) > 64:
            raise ProviderError('Malformed mask instances')
        for raw, score in zip(masks, scores):
            if not isinstance(score, (int, float)) or not 0 <= score <= 1:
                raise ProviderError('Invalid confidence')
            if score < .5:
                continue
            while isinstance(raw, list) and len(raw) == 1 and isinstance(raw[0], list) and raw[0] and isinstance(raw[0][0], list):
                raw = raw[0]
            if not isinstance(raw, list) or len(raw) != photo.height or any(not isinstance(row, list) or len(row) != photo.width for row in raw):
                raise ProviderError('Mask dimensions do not match original')
            pixels = bytearray()
            for row in raw:
                for value in row:
                    if not isinstance(value, (int, float)) or not 0 <= value <= 1:
                        raise ProviderError('Invalid mask value')
                    pixels.append(255 if value >= .5 else 0)
            mask = Image.frombytes('L', photo.size, bytes(pixels))
            box = mask.getbbox()
            if box is None:
                raise ProviderError('Empty detector mask')
            area = mask.histogram()[255]
            cut = photo.convert('RGBA')
            cut.putalpha(mask)
            cut = cut.crop(box)
            # A full rectangular opaque mask is not a transparent garment cutout.
            if cut.getchannel('A').getextrema() != (0, 255):
                raise ProviderError('Mask does not produce a transparent cutout')
            item = {'category': category, 'preview': png_uri(cut), 'prompt': tryoff_prompt(category),
                    'category_verified': False,
                    'mask_quality': {'status': 'unverified', 'source': 'detector_mask',
                                     'foreground_pixels': area, 'bbox': list(box),
                                     'image_size': list(photo.size), 'detector_score': score},
                    'quality_warnings': ['semantic_category_unverified', 'mask_completeness_unverified']}
            if area <= 3:
                item['quality_warnings'].append('small_mask')
            if box[0] == 0 or box[1] == 0 or box[2] == photo.width or box[3] == photo.height:
                item['quality_warnings'].append('image_boundary_contact')
            if len(item['quality_warnings']) > 2:
                item['mask_quality']['status'] = 'review_required'
            candidates.append((item, mask, area, score))
    # Resolve whole garments before deduplication, never subtract masks:
    # can destroy open jackets, overlapping layers and garment construction.
    one_piece = [c for c in candidates if c[0]['category'] in ('jumpsuit', 'dress')]
    candidates = [c for c in candidates if not (
        c[0]['category'] in ('trousers', 'skirt') and any(
            whole[2] >= c[2] * 1.25 and
            ImageChops.multiply(c[1], whole[1]).histogram()[255] / c[2] >= .9
            for whole in one_piece))]
    kept = []
    for candidate in sorted(candidates, key=lambda c: (-c[3], c[0]['category'])):
        item, mask, area, _ = candidate
        if any(ImageChops.multiply(mask, other).histogram()[255] /
               (area + other_area - ImageChops.multiply(mask, other).histogram()[255]) >= .85
               for _, other, other_area, _ in kept):
            continue
        kept.append(candidate)
    return [item for item, _, _, _ in kept]


SAM_VERSION = '1bf97763d5dfd3a1584adca913a8ef4b43c684fca97e04e39e4c50a3a5e09650'
SAM_SCHEMA_URL = 'https://api.replicate.com/v1/models/vufinder/sam3/versions/' + SAM_VERSION
FAL_MODEL = 'fal-ai/flux-2-klein/9b/base/edit/lora'
LORA = 'https://huggingface.co/fal/virtual-tryoff-lora/resolve/main/virtual-tryoff-lora_comfy.safetensors'


def original_image(value):
    try:
        if isinstance(value, str):
            if not value.startswith(('data:image/png;base64,', 'data:image/jpeg;base64,')):
                raise ValueError()
            value = base64.b64decode(value.split(',', 1)[1], validate=True)
        if not isinstance(value, bytes) or len(value) > 20 * 1024 * 1024:
            raise ValueError()
        image = Image.open(io.BytesIO(value))
        if image.width * image.height > 1_048_576 or image.format not in ('PNG', 'JPEG'):
            raise ValueError()
        image.load()
        return image.convert('RGB')
    except Exception:
        raise ProviderError('Invalid original image') from None


class RealProviders:
    @classmethod
    def from_env(cls, **kwargs):
        """Read environment only. Does not read secret files or contact providers."""
        import os
        return cls(os.environ.get('REPLICATE_API_TOKEN', ''), os.environ.get('FAL_KEY', ''), **kwargs)

    def _emit(self, provider, job_id, state):
        if self.event_callback is None:
            return
        import math
        metrics = {k: v for k, v in (state.get('metrics') or {}).items()
                   if k in ('predict_time', 'total_time', 'inference_time')
                   and isinstance(v, (int, float)) and math.isfinite(v) and v >= 0}
        status = state.get('status')
        if status not in ('starting', 'processing', 'succeeded', 'failed', 'canceled',
                          'IN_QUEUE', 'IN_PROGRESS', 'COMPLETED'):
            status = 'submitted'
        try:
            self.event_callback({'provider': provider, 'id': job_id, 'status': status, 'metrics': metrics})
        except Exception:
            # An observer failure must never cause a paid submission retry.
            pass

    def __init__(self, replicate_token, fal_key, *, transport=None, sleep=time.sleep,
                 clock=time.monotonic, deadline_seconds=120, max_polls=60, event_callback=None):
        self.event_callback = event_callback
        self.replicate_token, self.fal_key = replicate_token, fal_key
        self.http = SafeHTTP(transport=transport)
        self.sleep, self.clock = sleep, clock
        if not 0 < deadline_seconds <= 900 or not 0 < max_polls <= 300:
            raise ValueError('Invalid lifecycle bounds')
        self.deadline_seconds, self.max_polls = deadline_seconds, max_polls

    def _json(self, method, url, token=None, body=None, headers=None):
        try:
            value = json.loads(self.http.request(method, url, token=token, body=body, headers=headers))
            if not isinstance(value, dict):
                raise ValueError()
            return value
        except ProviderError:
            raise
        except Exception:
            raise ProviderError('Invalid provider JSON') from None

    def replicate_account(self):
        """Read-only credential identity; this endpoint does not report balance."""
        if not self.replicate_token:
            raise ProviderError('Replicate not configured')
        data = self._json('GET', 'https://api.replicate.com/v1/account', self.replicate_token,
                          headers={'Accept': 'application/json'})
        kind, username = data.get('type'), data.get('username')
        import re
        if kind not in ('user', 'organization') or not isinstance(username, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,100}', username):
            raise ProviderError('Invalid Replicate identity')
        return kind + ':' + username

    def credit_available_usd(self, action):
        """Read-only provider API credit; manual Replicate evidence lives in Store.

        Replicate account authentication is not a balance API.
        fal contract: https://fal.ai/docs/platform-apis/v1/account/billing
        """
        import math
        if action not in ('generate', 'tryon') or not self.fal_key:
            return None
        try:
            data = self._json('GET', 'https://api.fal.ai/v1/account/billing?expand=credits', self.fal_key,
                              headers={'Accept': 'application/json'})
            credits = data['credits']
            value = credits['current_balance']
            if credits['currency'] != 'USD' or type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                return None
            return value
        except Exception:
            return None

    def tryon_submit(self, person, clothing, *, before_submit):
        from virtual_tryon import VirtualTryOn
        return VirtualTryOn(self.fal_key).submit(person, clothing, before_submit=before_submit)

    def tryon_poll(self, request_id):
        from virtual_tryon import VirtualTryOn
        return VirtualTryOn(self.fal_key).poll(request_id)

    def detect(self, image, *, before_submit=None):
        photo = original_image(image)
        if not self.replicate_token:
            raise ProviderError('Replicate not configured')
        schema = self._json('GET', SAM_SCHEMA_URL, self.replicate_token)
        try:
            inputs = schema['openapi_schema']['components']['schemas']['Input']
            props = inputs['properties']
            expected = {'image': 'string', 'prompts': 'array', 'confidence_threshold': 'number',
                        'visualize': 'boolean', 'offset_masks': 'boolean', 'split_output': 'boolean',
                        'concat_input': 'boolean', 'backbone_output': 'boolean'}
            valid = (schema['id'] == SAM_VERSION and set(inputs['required']) == {'image', 'prompts'}
                     and all(props[k]['type'] == v for k, v in expected.items())
                     and props['prompts']['items']['type'] == 'string'
                     and props['offset_masks']['default'] is False)
            if not valid:
                raise ValueError()
        except Exception:
            raise ProviderError('Pinned SAM schema mismatch; no submission') from None
        body = {'version': SAM_VERSION, 'input': {'image': png_uri(photo),
                'prompts': [json.dumps({'text': c}) for c in CATEGORIES],
                'confidence_threshold': .5, 'visualize': False, 'offset_masks': False,
                'split_output': True, 'concat_input': True, 'backbone_output': False}}
        if before_submit is not None:
            before_submit()
        job = self._json('POST', 'https://api.replicate.com/v1/predictions', self.replicate_token,
                         body, {'Cancel-After': '40s'})
        job_id = job.get('id')
        if not isinstance(job_id, str) or not job_id.isalnum() or len(job_id) > 100:
            raise ProviderError('Invalid prediction identifier')
        self._emit('replicate', job_id, job)
        url = 'https://api.replicate.com/v1/predictions/' + job_id
        state = self._poll(url, self.replicate_token, 'succeeded', ('starting', 'processing'), 'POST', url + '/cancel')
        links = (state.get('output') or {}).get('results')
        if not isinstance(links, list) or len(links) > len(CATEGORIES):
            raise ProviderError('Invalid SAM output')
        return extract_items(photo, [self._json('GET', link) for link in links])

    def _poll(self, url, token, success, pending, cancel_method, cancel_url):
        deadline = self.clock() + self.deadline_seconds
        try:
            for _ in range(self.max_polls):
                if self.clock() >= deadline:
                    raise ProviderError('Provider deadline exceeded')
                state = self._json('GET', url, token)
                self._emit('replicate' if urlsplit(url).hostname == 'api.replicate.com' else 'fal',
                           url.rstrip('/').split('/')[-2 if url.endswith('/status') else -1], state)
                if state.get('status') == success:
                    return state
                if state.get('status') not in pending:
                    raise ProviderError('Provider job did not succeed')
                self.sleep(min(2, max(0, deadline - self.clock())))
            raise ProviderError('Provider poll bound exceeded')
        except BaseException:
            # Cancellation is best effort, never a refund or a resubmission.
            try:
                self.http.request(cancel_method, cancel_url, token=token, timeout=10)
            except Exception:
                pass
            raise

    def generate(self, original, item, *, before_submit=None):
        original_image(original)
        if not isinstance(original, str) or not self.fal_key:
            raise ProviderError('Original data URI and configured fal key required')
        prompt = tryoff_prompt(item.get('category'))
        body = {'prompt': prompt, 'image_urls': [original], 'loras': [{'path': LORA, 'scale': 1.0}],
                'image_size': {'width': 768, 'height': 1024}, 'num_images': 1,
                'num_inference_steps': 28, 'guidance_scale': 5, 'seed': 42,
                'acceleration': 'none', 'enable_safety_checker': True, 'output_format': 'png', 'sync_mode': False}
        if before_submit is not None:
            before_submit()
        job = self._json('POST', 'https://queue.fal.run/' + FAL_MODEL, self.fal_key, body)
        request_id = job.get('request_id')
        if not isinstance(request_id, str) or not request_id.replace('-', '').isalnum() or len(request_id) > 100:
            raise ProviderError('Invalid fal request identifier')
        # fal queue lifecycle is scoped to the base endpoint, not subpath.
        base = 'https://queue.fal.run/fal-ai/flux-2-klein/requests/' + request_id
        if job.get('status_url') != base + '/status' or job.get('response_url') != base:
            raise ProviderError('Untrusted fal lifecycle URL')
        self._poll(base + '/status', self.fal_key, 'COMPLETED', ('IN_QUEUE', 'IN_PROGRESS'), 'PUT', base + '/cancel')
        result = self._json('GET', base, self.fal_key)
        images = result.get('images')
        if not isinstance(images, list) or len(images) != 1 or any(result.get('has_nsfw_concepts', [])):
            raise ProviderError('Invalid or unsafe fal output')
        raw = self.http.request('GET', images[0]['url'])
        try:
            image = Image.open(io.BytesIO(raw))
            if image.format != 'PNG' or image.size != (768, 1024):
                raise ValueError()
            image.load()
        except Exception:
            raise ProviderError('Invalid generated PNG') from None
        return 'data:image/png;base64,' + base64.b64encode(raw).decode('ascii')

    def close(self):
        self.http.close()


class SafeHTTP:
    API = {'api.replicate.com': 'Bearer ', 'queue.fal.run': 'Key ', 'api.fal.ai': 'Key '}
    DOWNLOAD = {'replicate.delivery', 'v3.fal.media', 'v3b.fal.media', 'v3.fal.media', 'fal.media'}

    def __init__(self, transport=None, max_bytes=64 * 1024 * 1024):
        self.max_bytes = max_bytes
        self.client = httpx.Client(transport=transport, follow_redirects=False,
                                   verify=True, trust_env=False, timeout=30)

    def request(self, method, url, token=None, body=None, headers=None, timeout=30):
        try:
            u = urlsplit(url)
            host = u.hostname
            if (u.scheme != 'https' or host not in self.API.keys() | self.DOWNLOAD
                    or u.username or u.password or u.port not in (None, 443) or u.fragment):
                raise ProviderError('Untrusted provider URL')
            h = dict(headers or {})
            if token:
                if host not in self.API:
                    raise ProviderError('Credentials forbidden on download host')
                h['Authorization'] = self.API[host] + token
            with self.client.stream(method, url, headers=h, json=body,
                                    timeout=timeout, follow_redirects=False) as r:
                if not 200 <= r.status_code < 300:
                    raise ProviderError('Provider HTTP failure')
                if int(r.headers.get('content-length', '0')) > self.max_bytes:
                    raise ProviderError('Provider response too large')
                data = bytearray()
                for chunk in r.iter_bytes():
                    data.extend(chunk)
                    if len(data) > self.max_bytes:
                        raise ProviderError('Provider response too large')
                return bytes(data)
        except ProviderError:
            raise
        except Exception:
            raise ProviderError('Provider transport failed; not retried') from None

    def close(self):
        self.client.close()
