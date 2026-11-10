"""Virtual try-on provider adapter. No calls on import.

IMPORTANT: Call submit() only after the authenticated server has atomically
claimed a single-use quote/consent and checked the current fal credit balance.
Do not retry ambiguous POST failures: they may already have been billed.
"""
import re
import time
from urllib.parse import urlsplit

import httpx

MODEL = "fal-ai/image-apps-v2/virtual-try-on"
QUEUE = "https://queue.fal.run/" + MODEL
REQUEST_ID = re.compile(r"^[A-Za-z0-9_-]{1,100}$")

class TryOnError(RuntimeError):
    pass

def _image(value):
    if not isinstance(value, str) or len(value) > 8_000_000:
        raise TryOnError("invalid_image")
    if value.startswith("data:image/"):
        if not re.match(r"^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$", value):
            raise TryOnError("invalid_image")
    elif urlsplit(value).scheme != "https":
        raise TryOnError("invalid_image")
    return value

class VirtualTryOn:
    def __init__(self, fal_key, *, timeout=25):
        if not fal_key:
            raise TryOnError("fal_not_configured")
        self.key = fal_key
        self.timeout = timeout

    def _request(self, method, url, *, payload=None):
        try:
            with httpx.Client(timeout=self.timeout, follow_redirects=False) as client:
                response = client.request(method, url, headers={"Authorization": "Key " + self.key},
                                          json=payload)
            response.raise_for_status()
            result = response.json()
            if not isinstance(result, dict):
                raise ValueError()
            return result
        except (httpx.HTTPError, ValueError):
            raise TryOnError("provider_request_failed") from None

    def submit(self, person_image, clothing_image, *, before_submit):
        """Chargeable; before_submit must claim authorization exactly once."""
        if not callable(before_submit):
            raise TryOnError("approval_gate_required")
        body = {"person_image_url": _image(person_image),
                "clothing_image_url": _image(clothing_image),
                "preserve_pose": True}
        before_submit()
        data = self._request("POST", QUEUE, payload=body)
        rid = data.get("request_id")
        if not isinstance(rid, str) or not REQUEST_ID.fullmatch(rid):
            raise TryOnError("invalid_request_id")
        return rid

    def result(self, request_id, *, max_wait=180):
        """Poll one known request, never submit or retry a generation."""
        if not isinstance(request_id, str) or not REQUEST_ID.fullmatch(request_id):
            raise TryOnError("invalid_request_id")
        base = QUEUE + "/requests/" + request_id
        end = time.monotonic() + max_wait
        while time.monotonic() < end:
            state = self._request("GET", base + "/status").get("status")
            if state == "COMPLETED":
                data = self._request("GET", base)
                images = data.get("images")
                if not isinstance(images, list) or not images or not isinstance(images[0], dict):
                    raise TryOnError("invalid_result")
                url = images[0].get("url")
                if not isinstance(url, str) or urlsplit(url).scheme != "https":
                    raise TryOnError("invalid_result")
                return url
            if state in ("FAILED", "CANCELED"):
                raise TryOnError("generation_failed")
            if state not in ("IN_QUEUE", "IN_PROGRESS"):
                raise TryOnError("invalid_status")
            time.sleep(2)
        raise TryOnError("generation_pending")
