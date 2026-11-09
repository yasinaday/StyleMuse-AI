# Owner-only GitHub OAuth (staging backend contract)

No live deployment, credential enrollment, paid request, or quality acceptance is implied by this implementation. Keep `STYLEMUSE_ENABLED=false` until a separately authorized real owner login and readiness review. Existing visible-mask partial results and failed jacket reconstruction fidelity remain unaccepted.

## Configuration

All values are server-side environment variables. No provider key, private access token, GitHub client secret, or GitHub user access token belongs in browser code/storage.

- `STYLEMUSE_ORIGIN=https://yasinaday.github.io` (exact credentialed CORS/POST origin).
- `STYLEMUSE_GITHUB_OWNER_ID=87910425` (decimal **string** independently verified by the operator; never resolved or inferred from a login).
- `STYLEMUSE_GITHUB_OWNER_LOGIN=yasinaday` (both numeric ID and case-insensitive login must match GitHub `/user`).
- `STYLEMUSE_GITHUB_CLIENT_ID` and `STYLEMUSE_GITHUB_CLIENT_SECRET`: enroll privately after creating the GitHub OAuth App.
- `STYLEMUSE_GITHUB_REDIRECT_URI=https://stylemuse-api.129.121.148.187.sslip.io/api/auth/github/callback`: register this exact HTTPS callback; the server sends the identical configured URI on authorize and exchange. No request-supplied callback is used.
- `STYLEMUSE_GITHUB_RETURN_URL=https://yasinaday.github.io/StyleMuse-AI/`: pinned same-origin HTTPS return destination, no request-supplied `next`/redirect.
- `STYLEMUSE_OAUTH_STATE_TTL_SECONDS=600` (maximum 600; also bounded by the original session expiry).
- `STYLEMUSE_OWNER_LIFETIME_BUDGET_USD=0.50`: actual cap is the minimum of this value, its durable historical ceiling, and the durable global ceiling.
- `STYLEMUSE_OWNER_RATE_LIMIT=3`, `STYLEMUSE_OWNER_RATE_WINDOW_SECONDS=60`: rolling-window admission count persisted in SQLite. Detect and noncached generation each count once. Idempotent cached results do not submit providers or consume another admission.

Missing/unsafe OAuth configuration makes login return 503 `oauth_not_configured`. Enabled owner mode rejects incomplete configuration at startup. Setting either owner pin disables the legacy bearer bypass; legacy bearer behavior remains only for configurations with **neither** owner pin (compatibility/offline tests). Pin both fields in production.

## Browser contract

Every browser POST uses `credentials: 'include'`; browser sends exact Origin. Never send an Authorization bearer.

1. `POST /api/session` with no body: bootstrap/reuse the opaque `__Host-stylemuse_session` HttpOnly, Secure, SameSite=None, Partitioned cookie. In owner-configured mode response is `{status:'ok', enabled:boolean, authenticated:boolean, identity:null|{provider:'github',id:string,login:string}}`. Anonymous bootstrap is **not** paid authorization. In legacy no-owner mode the historical `{status,enabled}` response is retained.
2. `POST /api/auth/github/start`, existing partitioned session and exact Origin required: `{launch_url:string}`. Navigate top-level to the API `/api/auth/github/launch?ticket=...` URL. It sets a separate random `__Host-stylemuse_oauth_browser` HttpOnly/Secure/SameSite=Lax, nonpartitioned, host-only cookie, then redirects to the pinned Pages URL with a short-lived random `oauth_handoff` fragment. Neither the ticket nor provider URL alone grants authorization.
3. Pages immediately removes the fragment with `history.replaceState` and posts `{handoff:string}` to `/api/auth/github/handoff`, with its original partitioned cookie and exact Origin. Only the initiating session can exchange this one-use handoff for an API `/authorize` URL. Top-level `/authorize` requires the independent matching browser proof before redirecting to GitHub with random state and PKCE S256. Forwarding a launch URL puts the proof in the recipient browser but cannot complete the original session's handoff; forwarding authorize/provider URLs cannot pass the matching proof.
4. GitHub returns to `/api/auth/github/callback`. Under a lock, the server validates unique state, phase, expiry, session and matching independent proof before consuming the transaction. Unrelated browsers cannot consume it. Correctly bound denial, malformed code, exchange failure and wrong identity consume it and fail closed. The stored PKCE verifier is used server-side. Session, transaction generation and OAuth deadline are rechecked after provider I/O before authorizing the original session. A new start cancels prior in-flight login; logout/expiry/restart invalidate it. Success redirects only to the configured Pages URL without OAuth tokens or codes.
5. On returning to Pages call `POST /api/session` or `POST /api/health` again with credentials. `POST /api/health` adds existing global `reserved_usd` and `lifetime_budget_usd` fields, and in owner mode the same `authenticated`/`identity` fields. Public `GET /api/health` remains minimal `{status,enabled}` and never exposes account identity or costs.
6. `POST /api/auth/logout`, no body, exact Origin: `{status:'ok',authenticated:false,identity:null}`. Server revokes session, auth mapping and pending login states, and expires the Partitioned cookie. Re-bootstrap creates an anonymous session; it does not reset money/rate accounting.

Authentication alone does not enable inference: `enabled` must also be true, a provider configured, explicit cost confirmation present, and all storage/global/owner/rate/ambiguity guards pass. Anonymous paid calls always return 403 `paid_inference_not_authorized`; bearer-only calls in owner mode return 401. Durable owner admission failures: 402 `owner_budget_exceeded`, 429 `owner_rate_limited`; existing global 402 `budget_exceeded` and guard 409 `busy_or_ambiguous` remain.

OAuth failure JSON uses `error` only: `oauth_state_invalid` (403, expired/replayed/missing state/session), `oauth_denied` (403), `oauth_account_not_allowed` (403), `oauth_provider_failed` (502). Failed callbacks never redirect to a request-provided URL. Client should show an honest login failure/retry action. OAuth tokens/provider exceptions are redacted; successful token values are transient server memory only.

All normal API responses carry `Cache-Control: no-store` and `Referrer-Policy: no-referrer`. Configure the deployment/access proxy to redact callback query parameters from access logs; do not persist OAuth authorization codes/state in request logs. This change does not modify live logging configuration.

## Durable admission and lifecycle

SQLite `BEGIN IMMEDIATE` serializes owner budget, rolling-window count, existing global reservation, busy guard and job/claim insertion in one transaction. Failure rolls back all admission. Reservations remain charged after provider failure/ambiguous outcome; no automatic refund or retry. Existing global ledger/reserved values are never reset and its historical ceiling cannot increase. Owner ledger ceilings also cannot increase across restart, including a lower cap configured without another successful admission. Logout/new sessions/re-authentication retain the same `github:<numeric-id>` accounting identity.

Sessions, auth mappings and one-time state are bounded in-memory maps and fail closed on process restart. Run one API worker (or separately implement a shared session/state store before multiworker deployment); SQLite admission itself remains durable across processes/restarts. Local HTTPS Chromium tests verify real cross-site CHIPS/Lax cookie transport with a fixture consent/code/PKCE provider; they do not verify a real GitHub account login or provider output quality.
