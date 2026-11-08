# StyleMuse acceptance — 2026-11-08

Docker/HTTPS preview is deployed; production inference remains DISABLED. Real provider API transport succeeded but visual quality acceptance failed. GitHub publication is blocked by missing account credentials; Pages still serves the earlier commit.

Preview: https://stylemuse-api.129.121.148.187.sslip.io/
Authenticated endpoints: /api/health, /api/detect, /api/generate.

## Isolation and limits

Compose binds only 127.0.0.1:18920, UID 10001, read-only root filesystem, no capabilities, CPU/memory/PID limits and independent data mount. Secrets are outside Git at /opt/stylemuse-ai/secrets/runtime.env (0600). Caddy preserves existing SciVora routes and adds StyleMuse routes and static preview. Authentication is mandatory; CORS permits the GitHub Pages origin. This remains a private shared-token pilot, not a public multi-user identity service.

JPEG/PNG inputs retain the 16MP upload acceptance bound, then EXIF-correct and proportionately resize to <=1,048,576 pixels before hashing/storage/detection. Masks align with that same normalized reference. Generation uses the stored reference; output is 768x1024. App access token is session-only; provider credentials never reach the browser.

Runtime variables: STYLEMUSE_ACCESS_TOKEN, REPLICATE_API_TOKEN, FAL_KEY, STYLEMUSE_ENABLED (false by default), STYLEMUSE_LIFETIME_BUDGET_USD (zero by default), STYLEMUSE_DB_PATH, STYLEMUSE_STORAGE_DIR, STYLEMUSE_ORIGIN. The approved $0.50 is a total test ceiling, not a recurring budget. Durable reservations and claims survive restart; never reset them for retries.

## Results

- Backend: 25 passing tests, plus 2 nested subtests.
- Frontend: 9 passing tests, including real Chromium mobile 375x812.
- Live HTTPS/browser: HTTP 200, authenticated health, inference disabled, no horizontal overflow, no page JS errors, no token persisted to localStorage.
- Real sample: one SAM 3 detection and one fal.ai generation, both HTTP 200, no paid retries. Only the selected jacket was generated. Local-only test container stopped after evaluation; public inference remained disabled.
- Detected: jacket, trousers, bag, two separate shoes and jewelry.
- QUALITY FAIL: actual one-piece jumpsuit was mislabeled trousers and missed as jumpsuit. Generated jacket changed open-front construction to zipped/overlapped front and introduced unsupported labeling/lining and altered pocket/closure details. Clean background does not establish product fidelity. Generated output is white-background PNG, not transparent; detection previews retain alpha but have occlusion gaps.

fal account balance decreased $0.04; this is an account delta, not a per-job invoice. SAM measured runtime 3.66469818 seconds at $0.000975/sec gives estimated $0.00357308. Indicative combined cost about $0.0436; final provider invoice unverified. Durable reservation is $0.15 of the $0.50 ceiling, not actual billing.

Private evidence: /opt/stylemuse-ai/acceptance-20261108-final/. Do not publish the private photo, cutouts or provider responses. SciVora service file hashes and long-running PIDs were preserved.

## Free test commands

Run python -m pytest -q from server/ with pytest and pytest-subtests installed. STYLEMUSE_TEST_PHOTO can select an authorized private sample; the real-sample normalization test explicitly skips if unavailable. Offline tests never submit inference.

Run node --test tests/frontend/integration.test.cjs tests/frontend/browser.test.cjs after installing frontend dependencies and Chromium; set CHROMIUM_PATH as needed.

Further paid quality experiments need renewed explicit approval, not automatic retries. Production must remain disabled until quality and final publication acceptance pass. GitHub push needs user authorization through gh; never paste provider keys or GitHub tokens in chat.
