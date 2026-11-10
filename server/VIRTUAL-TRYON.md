# Owner-only virtual try-on

## Contract and price (verified 2026-11-10)

- Model: `fal-ai/image-apps-v2/virtual-try-on`.
- Official schema: https://fal.ai/models/fal-ai/image-apps-v2/virtual-try-on/api
- Official price: https://fal.ai/models/fal-ai/image-apps-v2/virtual-try-on — $0.04 per image.
- Payload: one `person_image_url`, one `clothing_image_url`, `preserve_pose: true`. No invented garment arrays; one returned image required.
- Queue lifecycle uses parent `fal-ai/image-apps-v2/requests/{id}`. Source: https://github.com/fal-ai/fal-js/blob/main/libs/client/src/queue.ts (`status` and `result` parse owner/alias and strip the subpath).

## Admission and recovery

Existing browser-bound GitHub OAuth, pinned owner ID, exact-origin cookies and server-only fal key are unchanged. `/api/quote` accepts `action: tryon`, bound to exact images, request identifier, owner and session for 90 seconds. `/api/tryon` requires that one-use quote, `confirmed: true`, and exact `max_total_usd: 0.04`; it rechecks fal credit both before durable admission and immediately before POST. Historical application ceilings are not enforced. Concurrency/rate/storage controls remain enforced.

The paid POST is attempted once. The ledger marks submission before transport. The queue identifier is saved durably in existing jobs. `/api/tryon/status` is owner-only, read-only with respect to the provider, and resumes the same request after transient polling errors or server restart (owner must log in again). Concurrent completion is compare-and-set serialized with ledger completion and guard release. Known failed/cancelled jobs release concurrency, retain ambiguous charge estimates and never auto-retry.

If the provider accepted a POST but the response or durable ID write failed, the job is deliberately not retried: billing/request identity is ambiguous and requires operator investigation. A job pending past the existing retention TTL may also need operator reconciliation. A missing original HTTP response is not proof of zero billing.

Inputs must be decoded bounded PNG/JPEG data URLs; arbitrary server-side image fetching is not implemented. Output is restricted to HTTPS fal CDN hosts, displayed directly by the browser. Saving or applying a later garment downloads through the browser with omitted credentials and no redirects; CORS/download failure stops that step, without a new inference. Saved results are local combination images, not automatic wardrobe writes.

## Mankenim

Person selection is local. Each selected wardrobe garment is applied sequentially, with its own fresh quote and explicit confirmation; each later step uses the previous result and may alter earlier garment details. Cancelling stops before that step's paid POST. There is no claim of native multi-garment support. Pending work can be checked with the free same-job button; optional save writes only the accepted result into local combinations.

## Verification scope

All provider results/balances in automated tests are fixtures. No paid inference was performed during implementation or rollout. Real visual fidelity, account generation locks, fal CDN CORS and physical-device owner flow remain unverified until separately approved evaluation. Existing baseline frontend paid-quote/manual-credit suites have four pre-existing failures, reproduced against unmodified 39a4d12; they are not silently claimed green.

TDD evidence: failing API quote (422 before support), missing queue poll/tryon credit gate, concurrent guard-release race, durable terminal failure and frontend cancellation/result/UI/terminal behavior logs are retained under `/root/.hermes/cache/scratch/stylemuse-tryon-20261110/`. Upload reading and explicit save were covered as integration/regression additions, not individually proven RED slices. No claim that every new helper independently followed a RED cycle.
