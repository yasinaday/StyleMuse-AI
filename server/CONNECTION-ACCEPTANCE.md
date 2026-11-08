# Connection acceptance — 2026-11-08

Implementation commit: 18517159c6737091bcce6810a59657bfc0df8868.

## Root cause and repair

The latest Pages UI called public GET /api/health, but the deployed API required a private bearer for that route. Browser requests also depended on a user-session token for which no enrollment endpoint existed. HTTPS itself and the Docker container were healthy. The local integration checkout lagged origin/main; the latest editorial UI was preserved.

GET health now returns only status/enabled. POST /api/session establishes an isolated opaque cookie session; authenticated POST health works without customer API-key entry. HttpOnly, Secure, SameSite=None, Partitioned, host-only Path=/ cookies, exact Origin checks and credentialed exact-origin CORS were verified. Cookie sessions are anonymous, not account login, have bounded in-memory capacity and TTL, and cannot authorize paid inference even if enabled=true. Provider keys and the private bearer stay server-side. A restart invalidates browser sessions; explicit retries bootstrap again without replaying a paid request.

Photo selection produces a local preview without uploading to an AI provider. Manual crop/save remains available. Analysis has a separate disabled-service check and confirmation; reviewed generated items still require explicit save. Production inference remains disabled.

## Executed checks

- Backend: 57 passed and 2 subtests passed; no failures. Existing dependency deprecation warnings remain.
- Frontend: 14 passed; no failures. Local real Chromium covers mobile file picker, decoded preview, manual crop/save, explicit confirmation and selected-item review. Provider responses in offline tests are fixtures, not real quality evidence.
- Deployed GitHub Pages: real Chromium mobile viewport 393x851, no API interception; POST session and POST health both succeeded cross-site without Authorization headers. Partitioned HttpOnly/Secure cookie accepted. Local photo preview decoded, no horizontal overflow, no page JavaScript errors. No detect/generate request occurred.
- HTTPS GET /api/health: 200, status ok, enabled false. Docker health: healthy.
- Exact-origin credentialed CORS preflight: passed. Untrusted session Origin: 403.
- SAM 3: authenticated read-only GET for the pinned vufinder/sam3 version returned 200, matching version and schema. No prediction submitted; this verifies API access/model metadata, not new segmentation quality.
- Tracked repository files contain none of the configured provider/private access secret values.
- Only the StyleMuse API container was recreated. Shared Caddy configuration/process was not changed or restarted. SciVora service PIDs/states matched the pre-change baseline.

## Gates and limits

No paid AI operation ran during this repair. Historical reservation state was preserved. Real-device Android/Safari testing was not performed; mobile Chromium emulation and deployed CHIPS acceptance were tested. Anonymous sessions do not implement account identity or permission to buy/run AI. Real segmentation quality and paid activation remain separate approval gates. Style Score and payment work are deferred.

Local live-browser evidence (not published with private runtime material): /root/.hermes/cache/scratch/stylemuse-connect/live-result.json and pages-mobile.png. Public HTTPS preview was synchronized with the same index.html.
