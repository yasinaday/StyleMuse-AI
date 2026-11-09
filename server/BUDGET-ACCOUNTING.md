# Budget accounting contract (offline preparation)

Authenticated `POST /api/health` retains `reserved_usd` and
`lifetime_budget_usd` and adds:

- `spent_usd`: reservation estimates for newly audited operations whose usable
  result was successfully stored. **Not actual billed cost.**
- `pending_usd`: all other retained reservation estimates, including legacy
  history, in-flight work, ambiguous submissions and failed submitted work.
  Pending does not promise a later refund.
- `remaining_usd`: max(0, lifetime ceiling minus retained reservations).

The invariant is `reserved_usd = spent_usd + pending_usd` (apart from JSON
floating-point representation). Admission continues using integer microdollars
and the existing durable global/owner ceilings. No ceiling is increased. Public
GET health remains unchanged. A frontend talking to an old backend should use
`reserved_usd` for retained/unknown estimates, **not** label it actual spend;
calculate remaining from the existing ceiling and reservation fields when new
fields are absent. Do not display missing `spent_usd` as verified zero billing.

## Minimal migration and future evidence

One additive `operations` table; no existing ledger/job/claim columns or rows are
rewritten. Each new detect and each generated item has an operation key linked
to its job/item, owner, integer reservation amount and durable state. Admission,
audit creation, and job/claim creation share one SQLite writer transaction.

`reserved -> submitted` is committed immediately before a real provider's paid
POST (after local validation/schema preflight). Failure to persist this boundary
prevents the POST. Unknown/custom adapters are conservatively marked submitted
before invocation. No inference creation retry is added. Success moves to
`spent` without decreasing retained reservations. Failed submitted work remains
`submitted`/pending even on HTTP rejection, timeout, cancellation, bad output,
or result-storage failure: none establishes a billing refund.

Only a live unwound failed/cancelled invocation that still has `reserved` state
can move to `released`, atomically decrementing both global and owner retention.
This also releases never-started later items in a failed generation batch.
Released and completed rows remain as tombstones and cannot be refunded twice.
Rate-limit admissions and request/job/claim tombstones are not erased.

A restart does NOT sweep outstanding operations or clear the guard. In
particular it does not release a crashed reserved row. A crash after durable
submission but before an actual POST may over-retain funds intentionally.

## Historical reconciliation limits

Existing accumulated reservations are retained in full, classified pending /
unknown rather than invented actual spend. Done jobs/claims prove local result
completion, not invoice amounts. A claimed job with no result does not prove
non-submission, provider rejection, or free cancellation. Neither an account
balance nor multiplying counts by current estimates establishes actual billing
or a refund. No automatic historical correction is provided.

A separately authorized manual reconciliation would need trustworthy retained
per-request provider IDs / submission evidence and provider billing or refund
records, or conclusive durable evidence no submission occurred. Reconcile exact
operations and owner/global amounts together with a retained adjustment audit;
never delete old history or infer refundable amounts from missing results.
The new audit does not itself capture provider invoice amounts/IDs and is not a
billing reconciliation system.

## Execution boundary

Source prepared offline only: no production database migration, restart,
deployment, paid request, or commit. Existing process-local sessions must remain
untouched. Run tests with `STYLEMUSE_DB_PATH` and `STYLEMUSE_STORAGE_DIR` set to
fresh scratch locations **before importing app**, and `STYLEMUSE_ENABLED=false`.
The module-level application constructor otherwise opens the configured DB.
