# Manual Replicate Billing evidence (2026-11-10)

## Contract

- No general application spending ceiling. Existing application admission already
  uses `Store.reserve(..., enforce_budget=False)` for detect and generate; this
  change retains that policy. Legacy ledger/period ceiling columns are historical
  evidence, not renewed limits. Their values and all existing history remain intact.
- Every paid operation still requires owner authentication, an exact server quote,
  explicit single-use confirmation, input/session/owner binding, 90-second expiry,
  durable writer-serialized reservation and replay/concurrency guards. No automatic
  provider creation retry is introduced. fal.ai still uses its read-only credit API.
- Replicate's documented `GET /v1/account` authenticates the token and reports
  `type`/`username`, **not balance**. The official OpenAPI document has no path named
  balance/billing/credit. Do not use undocumented dashboard endpoints or inference
  as a balance probe.
- A separately authorized operator command binds the user-reported Billing amount
  to that live read-only account identity and server receipt time. It is explicitly
  `manual_non_realtime`, expires 24 hours after receipt, and is not API-verified
  credit or a new spending grant. Reusing the snapshot ID cannot refresh its time,
  overwrite its evidence, or replenish consumed estimates.
- Each detect submission durably debits its estimate from the snapshot in the same
  transaction that marks the operation submitted, **before provider POST**. Success
  and ambiguous failures retain that debit across restart; pre-submission failures
  do not debit. The snapshot and remaining estimate are rechecked under the writer
  lock. A refreshed snapshot invalidates previous quotes, including refresh racing
  with admission. Busy admission prevents operator snapshot replacement.
- This is not a guaranteed provider billing cap: external usage, actual charges
  exceeding estimates and delayed billing can exhaust credit or cause overspend.
  The confirmation dialog shows manual status, available estimate, server receipt
  time, non-realtime status and overspend risk before the user approves.

## Operator enrollment, only after independent review

`server/record_replicate_balance.py` has no HTTP enrollment counterpart. Load the
**existing** environment securely (never rotate or print the key), explicitly set
`STYLEMUSE_ENABLED=false`, `STYLEMUSE_DB_PATH=/data/state.sqlite3`, and
`STYLEMUSE_STORAGE_DIR=/data/images` in the isolated operator process using the
actual mounted `/opt/stylemuse-ai/runtime/data:/data`. Take another online SQLite
backup if production history has changed since review. Run the reviewed image:

```text
python /app/record_replicate_balance.py \
  --snapshot-id replicate-user-billing-20261110-092 \
  --amount .92 \
  --evidence 'User explicitly verified Replicate Billing USD 0.92 on 2026-11-10; no general application spending ceiling; per-operation consent required; manual non-realtime evidence'
```

This command makes **only a GET account request**, never a prediction. It writes
only the new snapshot and creates additive schema; no ledger grant/reset or key
change. Source imports must be disabled and pointed at the intended DB *before*
importing `app`, because module-level app construction opens Store.

Do not deploy before independent approval of the frozen source. Recreate only the
StyleMuse service after approval; process-local sessions require owner re-login.
Verify deployed source hashes, unchanged credential fingerprints, mounted history
and other workload PIDs, local/public health, then a free staging/live preflight
without calling `/api/detect`, `/api/generate`, or provider prediction POST.
Frontend is `index.html`; deploy its matching reviewed version through the existing
Pages process, not a new design.

## Evidence and tests

- Retained RED/GREEN and final test logs:
  `/opt/stylemuse-ai-integration/evidence/manual-credit-tdd/`
- Actual mounted online backup, restricted baseline with secret fingerprints,
  free-preflight program and report:
  `/root/.hermes/cache/scratch/stylemuse-manual-credit-20261110/`
- Backup source: `/opt/stylemuse-ai/runtime/data/state.sqlite3`.
- Free staging quote uses an online-backup copy, real account GET, and an explicitly
  fixture owner session. It is **not deployed admission** or real owner login.
- Core new regressions: `server/test_manual_credit.py`,
  `tests/frontend/manual-credit.test.cjs`. Existing paid-quote/OAuth/accounting suites
  remain acceptance gates. No paid provider tests were run.

Official sources fetched successfully on 2026-11-10 (retained raw documents and
parsed facts under the evidence directory):
- https://replicate.com/docs/reference/http
- https://api.replicate.com/openapi.json
- https://replicate.com/docs/topics/billing
