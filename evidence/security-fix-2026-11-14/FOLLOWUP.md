# PR11 frontend follow-up — offline implementation evidence

HEAD remains `05a7e32093377f4af2a63a50ccfd1e3516cbe9db`. No commit, push, merge, deployment, live API call, paid provider call, service/config/DB change. Security acceptance remains Yasin's; parent handles any separately authorized release.

## Changes
- `index.html`: extract the backup parser's exact allowlisted data-image predicate into `safeBackupImage`; reuse it for profile startup. PNG and JPEG profiles now survive actual backup restore and a subsequent reload. Existing backup formats (JPEG/PNG/WebP/GIF) and rejection semantics remain unchanged.
- `index.html`: all three paid operations use `approvePaidQuote`. Quote is obtained BEFORE the SAME native Stil Jetonu dialog shows token count and the server's **total** estimated provider USD amount. The dialog expressly says it is not an additional user charge/payment. No client multiplication or rounding of server cost. Only approval returns the displayed quote for exact `quote_id` / `max_total_usd` / `confirmed:true` submission.
- Quote lease is validated against server `expires_in_seconds` (positive, at most 90). Time is measured conservatively from request start using both monotonic and wall clocks. An approval after lease expiry discards that quote, requests another, and requires a new dialog approval. Cancellation returns without paid submission. No paid-request automatic retry was added.
- Generation uses one server total for the exact selected item IDs; zero-cost cached generation remains valid. Each sequential try-on part has its own quote, one-token/cost dialog and approval; the previous aggregate approval was removed. Existing positive try-on cost rule is retained.
- `tests/frontend/followup-consent.test.cjs`: 16 new real Chromium test methods. Coverage: analyze approval/cancel; multi-item generation total/approval/cancel; monotonic expiry renewal plus accept/cancel; wall-clock/device-sleep renewal with changed displayed amount; try-on cancellation at first/second step and full two-step approval; generation/try-on expiry cancellation; invalid quote matrix plus cached zero-cost generation; real aiPost/session/fetch transport through offline fulfilled HTTP routes; actual PNG/JPEG backup restore and reload.

## Actual server contract inspected
`server/app.py:658-717`: quote binds owner/session/digest/amount/action and is single use; exact Decimal cost confirmation is required; expiry uses server time + 90 seconds. Response includes `quote_id`, `action`, `estimated_cost_usd`, `expires_in_seconds:90`. Detect uses configured reservation; generation total is reservation times uncached selected items; try-on quote is $0.04. Provider credit/manual balance metadata is deliberately not an admission gate. No backend or balance/mask policy was changed.

## TDD evidence (logs are retained, not overwritten)
- `01-profile-red.tap` → `02-profile-green.tap`: real PNG avatar failure then fix; JPEG control already passed.
- `03-analysis-red.tap` → `04-analysis-green.tap`: missing USD in actual token dialog then fix.
- `05-generation-red.tap` → `06-generation-green.tap`: approval before quote then fix.
- `07-expiry-red.tap` retains initial missing-renewal timeout; `08-expiry-assertion-red.tap` proves expired quote was submitted; `09-expiry-green.tap` proves renewal/new approval.
- `10-tryon-red.tap` retains initial missing-per-step-quote timeout; `11-tryon-assertion-red.tap` proves quote count 0 at approval; `12-tryon-green.tap` proves independent steps.
- `13-invalid-red.tap` → `14-invalid-green.tap`: shared helper temporarily allowed zero-cost try-on; preserve existing positive-cost rule. Invalid types/action/id/TTL/cost and cached generation control included.
- `17-wall-expiry-red.tap` → `18-wall-expiry-green.tap`: suspended monotonic clock must not extend server lease.
- Later transport/action-specific expiry cases are additional regression coverage, not retrospectively claimed RED tests.

## Final results — do not add repeated runs together
- FINAL frontend selected combined run: `22-final-network-isolated-frontend.tap`: **48 test methods, 26 PASS / 22 FAIL, no skips/cancellations**. This is the original 32 (10 PASS / same 22 FAIL) plus new 16/16 PASS. Programmatic comparison against retained prior PR11 TAP finds **zero new or removed failing IDs**. Existing assertions and old tests were not edited or weakened.
- Backend full offline rerun: `16-backend-full.log`, `backend-full/results.xml`: JUnit declared outcomes including subtests **242 = 222 PASS / same 19 FAIL / 1 existing private-photo skip / 0 errors**. There are **230 top-level testcases** (210 passing, 19 failing, 1 skipped); pytest's console separately says 211 passed plus 11 passing subtests. Preserve these distinctions rather than treating nested outcomes as unique methods.
- Backend security-focused rerun: `21-backend-focused.log`, `backend-focused/results.xml`: **89/89 PASS** (image-security, sessions, OAuth, browser binding, owner-budget). Full suite's 19 failure IDs match retained prior PR11 XML exactly. Warnings are existing Python/FastAPI/Starlette deprecations, not suppressed.
- Existing old frontend failures remain stale mock/API expectations (including the prior mixed consent fixtures); backend failures remain the already classified removed balance/manual-admission expectations and obsolete empty-mask expectation. Full historical failure names and comparison are in `comparison-final.json`; no unrelated policies were silently repaired.
- `git diff --check`: PASS. All 54 tracked server/frontend-test files are byte-identical to HEAD; only tracked production edit is `index.html`, plus the new untracked frontend test file.

## Environment and isolation
Node v26.11.0; Playwright 1.65.0; real headless Chromium 158.0.8127.18. New browser tests disable background networking/component update, block service workers and DNS, and abort every route except the synthetic offline HTML or explicitly fulfilled fixture HTTP responses. Synthetic images and provider/API responses are test fixtures, not live/provider results. Most UI cases mock the aiPost boundary; one explicitly exercises unchanged real session/aiPost/aiRequest/fetch via fulfilled HTTP. Backend reruns use retained Python 3.14.7 / Pillow 13 environment, copied sources in evidence, cleared provider/auth environment, and blocked socket connect/DNS. Not a Docker/Python 3.12 or live-photo acceptance claim.

## Final source hashes
Canonical latest manifest: `FINAL-HASHES-AND-TESTS.json` (includes 16 added method IDs and all 22 unchanged frontend failure IDs).

- index.html: `9e5c127f8e1b2933cc635f633054ff5c7b04385efadbf72075ea5c54748f9e9f`
- tests/frontend/followup-consent.test.cjs: `80b3fe633c28200e22ad55814042a283e7c389d02d72ca7b4e3d00a7d53bacd8`
- unchanged server/app.py: `f10e3b68322d5e5ecd65919dc02e6462bb8340255ee0752ec448ac7713d38b7d`

`pre-regression-hashes.json` and `final-source-hashes.json` are retained intermediate manifests; the latter predates the final test-only network-isolation flags. `comparison.json` is an intermediate top-level-only XML parser output (230 testcases); `comparison-final.json` corrects its naming and explicitly records declared subtest-inclusive totals. No historical logs were replaced.

Remaining gates: independent review/security acceptance by Yasin; parent release decision. No merge/deploy performed or authorized by these PASS results alone.
