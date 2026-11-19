# Android acceptance / backend release gate — 2026-11-19

Status: source/offline accepted only. No production deployment or payment authorized/performed. APK debug signing is not Play App Signing.

## Prepared safe configuration

`play.env.example` sets the source package identity only. It deliberately omits catalog, account secret, signing identity and ADC credentials. Do not load it as a replacement for the existing effective Compose environment. Missing billing configuration must keep purchases disabled.

## Required owner settings, individually

1. Confirm Play Console app ownership for `com.stylemuse.ai` (source identity confirmed; Console ownership unverified).
2. Set `STYLEMUSE_PLAY_PACKAGE=com.stylemuse.ai` in an additive release overlay after Console confirmation.
3. Approve real one-time product IDs and integer credit amounts; encode the exact mapping as `STYLEMUSE_PLAY_CATALOG`. No production IDs/credits/prices were supplied; test fixtures are not a catalog.
4. Generate and persist `STYLEMUSE_PLAY_ACCOUNT_SECRET` (32+ bytes) in the approved secret store before activation. Never commit/embed it or rotate it casually; receipt ownership uses its HMAC.
5. Set `STYLEMUSE_PLAY_SIGNING_SHA256` to the verified intended signing certificate, not an assumed debug/upload certificate. This field is metadata and does not prove device integrity.
6. Enable Android Publisher API for the approved Cloud project and choose backend ADC identity. ADC availability is unverified; missing GOOGLE_APPLICATION_CREDENTIALS alone does not prove no ADC exists.
7. Invite that service account in Play Console with app-scoped visibility, financial-data access, and orders/subscriptions management. Cloud IAM alone is insufficient. Do not invent a legacy project-link requirement.
8. If file ADC is approved, mount only the credential file read-only, readable by container UID 10001, outside /data; use GOOGLE_APPLICATION_CREDENTIALS. Never place it in source/image.
9. Create/activate the real one-time products, BUY option, localized metadata, approved regional prices/availability. Multi-quantity must remain unsupported because server accepts quantity 1 only.
10. Configure genuine upload signing, Play App Signing identity, versioned release AAB and internal-testing availability; current artifact is debug APK only.
11. Confirm tester region/opt-in and separately add the actual Google purchase account to license testing. Test-track membership alone does not prevent real charges. No purchase test is authorized here.
12. Verify Google OAuth package/certificate/client IDs against the Play-delivered signing identity and actual backend audiences. Populated settings are not real-login proof.
13. Resolve durable consumption retry, RTDN/voided-purchase/refund reconciliation before public launch. Current ledger retains token hash; retry depends on device redelivery, not a proven durable server queue.

Official references: Android Publisher getting_started; Android Billing security and test documentation; Play Console Help one-time products and user permissions. Full inspected settings and references are in the tooling play-release-followup.txt report.

## Required backend changes

Deploy this branch's complete server snapshot (app.py/store.py/providers.py/admin_diagnostics.py/play_billing.py and requirements/build dependencies), not copied single routes. This includes authenticated account avatar upload/readback, account_avatars schema, account-bound billing configuration/verification and receipt deduplication, native admin diagnostics, identity protections, provider-credit admission fixes. Avatar is normalized PNG/JPEG, stored in SQLite, scoped to verified Google subject. Billing is fail-closed until configuration exists.

The live image observed was `stylemuse-api:android-auth-dc27f47`, image ID `sha256:7d2c4d4ea3e9cadfb5c1fbc50cc98b07f69c6ae667444288b1be5e632d3d6022`. It lacks the new billing module/routes and custom avatar endpoint. Do not claim these work on the phone against that image.

## Backup and rollout plan

A consistent SQLite backup and complete effective Compose input copies were prepared privately at:
`/opt/stylemuse-tooling/resume-20261119/followup/backup-20261119T144356Z`
SQLite integrity_check and integrity of a separately restored DB copy both returned ok. This is not a full image-files backup or user-workflow restoration proof. Re-take the backup immediately before any approved deployment; preserve /data/images under a quiesced full-data backup as well.

1. Freeze source commit; use successful isolated offline tests, build immutable candidate image in a new release directory. Never run tests against /data.
2. Preserve all six existing Compose overlays (private backup manifest records exact order), old image, OAuth/provider settings, UID 10001, read-only root, writable /data, loopback-only 18920 bind, limits and security settings.
3. Exercise candidate imports and account/avatar/billing fail-closed contracts on disposable storage and loopback-only canary. No real receipts or paid providers.
4. Obtain explicit deployment approval; recreate only Compose project server/service api with the entire existing stack plus additive image/config overlay. Do not touch unrelated services or enable billing by guessing missing values.
5. Read back image ID, mounts, user, security/env names and health. Verify source/route versions and authorized real-account upload/readback separately. No device access means no real Google/Play acceptance claim.

## Rollback

Triggers: startup/health failure, auth/account leakage, credits regression, wrong catalog, duplicate credit or unsafe consume retry. Disable new purchase entry; preserve pending verification/recovery where safe. Restore the prior complete image/Compose stack, preserving current database, account secret and receipt ledger. Never automatically restore an older DB: it can erase credits/dedup and allow duplicate grants. Database rollback requires maintenance, post-backup reconciliation and explicit owner approval. Keep all evidence private; recheck health and old account flow. No production change was made in this task.

## Former 18 server failures

Fixed implementation omissions: unknown-credit preflight (1); manual-credit disclosure/snapshot/owner/expiry/debit checks (8); malformed/insufficient quote/submission credit checks (7); per-item generation recheck (1); try-on submission credit recheck (1). Exact test IDs and original RED/final GREEN logs: `/opt/stylemuse-tooling/resume-20261119/server-followup-report.txt`. Offline final source suite: 282 tests and 12 subtests passed; dependency deprecation warnings remain. No external provider/payment verification is implied.
