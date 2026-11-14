"""Harmless offline fixtures: no exploit payloads, private photos or providers."""
import ast
import base64
from io import BytesIO
from pathlib import Path

import pytest
import httpx
from PIL import Image
from fastapi import HTTPException
import app as api
import providers


def fixture(fmt='PNG', size=(4, 3)):
    out = BytesIO()
    Image.new('RGB', size, 'navy').save(out, fmt)
    return out.getvalue()


def uri(raw):
    return 'data:image/png;base64,' + base64.b64encode(raw).decode('ascii')


def test_all_production_image_opens_restrict_plugins():
    found = 0
    for name in ('app.py', 'providers.py'):
        tree = ast.parse(Path(__file__).with_name(name).read_text())
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name) and node.func.value.id == 'Image' and node.func.attr == 'open':
                found += 1
                formats = next((k.value for k in node.keywords if k.arg == 'formats'), None)
                assert formats is not None, f'{name}:{node.lineno} has unrestricted plugin dispatch'
                assert set(ast.literal_eval(formats)) <= {'PNG', 'JPEG'}
    assert found == 3


def test_original_encoded_limit_precedes_base64_allocation(monkeypatch):
    calls = []
    def decode(*args, **kwargs):
        calls.append(True)
        return fixture()
    monkeypatch.setattr(providers.base64, 'b64decode', decode)
    oversized = 'data:image/png;base64,' + 'A' * ((20 * 1024 * 1024 + 2) // 3 * 4 + 1)
    with pytest.raises(providers.ProviderError, match='Invalid original image'):
        providers.original_image(oversized)
    assert calls == []


def test_pillow_pin_matches_verified_advisory_fix():
    # Both upstream advisories name 13.0.0 as the first patched release.
    assert 'Pillow==13.0.0' in Path(__file__).with_name('requirements.txt').read_text().splitlines()


def generated(raw):
    """Exercise real adapter control flow with an entirely in-memory transport."""
    def handler(request):
        if request.method == 'POST':
            base = 'https://queue.fal.run/fal-ai/flux-2-klein/requests/offline'
            return httpx.Response(200, json={'request_id': 'offline', 'status_url': base+'/status', 'response_url': base})
        if request.url.path.endswith('/status'):
            return httpx.Response(200, json={'status': 'COMPLETED'})
        return httpx.Response(200, json={'images': [{'url': 'https://v3.fal.media/offline.png'}]})
    adapter = providers.RealProviders('offline', 'offline', transport=httpx.MockTransport(handler))
    original_request = adapter.http.request
    def request(method, url, *args, **kwargs):
        if url == 'https://v3.fal.media/offline.png':
            return raw
        return original_request(method, url, *args, **kwargs)
    adapter.http.request = request
    try:
        return adapter.generate(uri(fixture()), {'category': 'top'})
    finally:
        adapter.close()


def test_generated_bytes_limit_before_open(monkeypatch):
    # A bytes subclass simulates the boundary without allocating 64 MiB.
    class Oversized(bytes):
        def __len__(self):
            return 64 * 1024 * 1024 + 1
    raw = Oversized(fixture(size=(768, 1024)))
    opens = []
    real_open = Image.open
    def observe(fp, *args, **kwargs):
        opens.append(True)
        return real_open(fp, *args, **kwargs)
    monkeypatch.setattr(Image, 'open', observe)
    with pytest.raises(providers.ProviderError, match='Invalid generated PNG'):
        generated(raw)
    assert len(opens) == 1  # Only the original image was opened.


@pytest.mark.parametrize('fmt', ['PNG', 'JPEG'])
def test_supported_images_reencode_and_keep_dimensions(fmt):
    raw = fixture(fmt)
    result = api.normalize(uri(raw), api.Settings(), upload=True)
    assert result.startswith('data:image/png;base64,')
    assert providers.original_image(result).size == (4, 3)
    assert providers.original_image(raw).size == (4, 3)


@pytest.mark.parametrize('fmt', ['GIF', 'BMP', 'TIFF'])
def test_unsupported_formats_are_rejected_even_with_png_mime(fmt):
    raw = fixture(fmt)
    with pytest.raises(HTTPException) as error:
        api.normalize(uri(raw), api.Settings(), upload=True)
    assert (error.value.status_code, error.value.detail) == (422, 'invalid_image')
    with pytest.raises(providers.ProviderError, match='Invalid original image'):
        providers.original_image(raw)
    with pytest.raises(providers.ProviderError, match='Invalid generated PNG'):
        generated(raw)


def test_excluded_xbm_plugin_is_never_dispatched(monkeypatch):
    from PIL import XbmImagePlugin
    def forbidden(*args, **kwargs):
        pytest.fail('Excluded XBM plugin was dispatched')
    monkeypatch.setitem(Image.OPEN, 'XBM', (forbidden, XbmImagePlugin._accept))
    # Ordinary, valid, tiny XBM; deliberately not the advisory's ReDoS payload.
    raw = b'#define tiny_width 1\n#define tiny_height 1\nstatic char tiny_bits[] = {0x00};\n'
    with pytest.raises(HTTPException):
        api.normalize(uri(raw), api.Settings(), upload=True)
    with pytest.raises(providers.ProviderError):
        providers.original_image(raw)
    with pytest.raises(providers.ProviderError):
        generated(raw)


def test_upload_byte_limit_precedes_image_open(monkeypatch):
    raw = fixture()
    def forbidden(*args, **kwargs):
        pytest.fail('Image opened before byte limit')
    monkeypatch.setattr(Image, 'open', forbidden)
    with pytest.raises(HTTPException):
        api.normalize(uri(raw), api.Settings(max_image_bytes=len(raw)-1), upload=True)


def test_original_byte_limit_precedes_image_open(monkeypatch):
    class Oversized(bytes):
        def __len__(self):
            return 20 * 1024 * 1024 + 1
    raw = Oversized(fixture())
    def forbidden(*args, **kwargs):
        pytest.fail('Image opened before byte limit')
    monkeypatch.setattr(Image, 'open', forbidden)
    with pytest.raises(providers.ProviderError):
        providers.original_image(raw)


def test_upload_pixel_limit_precedes_decode_and_exif(monkeypatch):
    from PIL import PngImagePlugin
    raw = fixture()
    def forbidden(*args, **kwargs):
        pytest.fail('Pixel limit must precede EXIF and full decoding')
    monkeypatch.setattr(PngImagePlugin.PngImageFile, 'load', forbidden)
    monkeypatch.setattr(Image.Image, 'getexif', forbidden)
    with pytest.raises(HTTPException):
        api.normalize(uri(raw), api.Settings(max_pixels=11), upload=True)


def test_original_pixel_limit_precedes_decode(monkeypatch):
    from PIL import PngImagePlugin
    raw = fixture(size=(1025, 1024))
    def forbidden(*args, **kwargs):
        pytest.fail('Pixel limit must precede full decoding')
    monkeypatch.setattr(PngImagePlugin.PngImageFile, 'load', forbidden)
    with pytest.raises(providers.ProviderError):
        providers.original_image(raw)


def test_generated_wrong_dimensions_precede_decode(monkeypatch):
    from PIL import PngImagePlugin
    raw = fixture(size=(5, 4))
    load = PngImagePlugin.PngImageFile.load
    def guarded(image, *args, **kwargs):
        if image.size == (5, 4):
            pytest.fail('Invalid generated dimensions decoded')
        return load(image, *args, **kwargs)
    monkeypatch.setattr(PngImagePlugin.PngImageFile, 'load', guarded)
    with pytest.raises(providers.ProviderError, match='Invalid generated PNG'):
        generated(raw)


def test_generated_png_supported():
    raw = fixture(size=(768, 1024))
    assert generated(raw) == uri(raw)


def test_upload_limits_are_inclusive():
    raw = fixture()
    assert api.normalize(uri(raw), api.Settings(max_image_bytes=len(raw), max_pixels=12))
