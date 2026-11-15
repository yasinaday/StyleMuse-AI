# Android phone fixes — 2026-11-15

## Scope and preservation

Native Flutter Android app only. No backend deployment, paid inference, account credential guessing, purchases, or changes to other services. Inherited unfinished native sources and tests are included in this branch rather than discarded.

Pre-edit dirty tracked diff and complete untracked archive: `/root/.hermes/cache/scratch/stylemuse-resume-20261115-181337/`.

## Verified final source

- `flutter analyze`: no issues (`/opt/stylemuse-tooling/phone-final3-analyze.log`).
- `flutter test`: **59 passed**, none failing (`phone-final3-test.log`).
- `flutter build apk --debug`: success (`phone-final3-build.log`).
- Socket/transport failures are converted to fixed safe API error codes with no automatic POST retry; existing timeout/recovery tests now assert the typed timeout boundary.
- Empty mannequin CTA is wired to Giysiler. Regression was observed failing before callback wiring, then passed. Empty-page tests scroll lazy content into view instead of assuming a fixed swipe distance.
- Recovery affordance is based on durable pending state; operation error snackbars provide a recovery action only when pending exists. Generic failures without pending no longer tell the user to find an absent recovery button.
- Existing injected tests cover local gallery/crop/category/save, account-required extraction, declined consent, durable recovery including storage failure/retry, and inference-free navigation. These tests do not contact paid providers.
- Cost contracts remain one token/photo, one token/try-on garment, two tokens/enhanced garment. Price regression tests pass; purchasing stays disabled. Explicit light theme preserved.

## Google connection evidence — unresolved production readiness

Safe cookie-aware HTTPS probes are retained in `/opt/stylemuse-tooling/phone-safe-api-evidence.json`; no cookie, token, client ID value, user identity, or raw provider exception is printed.

- POST `/api/session`: 200.
- POST `/api/account` using that session: 200; Google client ID is configured, no Google user authenticated.
- POST `/api/auth/google/android` with an empty body: **404**. This is the exact endpoint used by the native client. The deployed server does not expose a working native Google sign-in route. This proves a backend readiness blocker, not that it was the only error on the user's phone.
- Native plugin `ApiException: 10` is mapped to `google_oauth_configuration_error` in a mocked method-channel regression test, without leaking account/message data. There is no captured real-account plugin error in this session, so Android OAuth package/signing-client registration remains unverified. No client IDs or credentials were guessed, no OAuth policy was relaxed, and no backend was activated.
- UI now distinguishes configuration/developer errors, absent Android backend route, and connectivity failures with safe messages.

## APK and upgrade evidence

Artifact: `/opt/stylemuse-tooling/artifacts/stylemuse-phone-fixes-20261115-debug.apk`

SHA-256: `eb49ea126c4ca9097b27fdb3a67434805642cc7cd1d0d8824cff89240445c73a`

Package: `com.stylemuse.ai`, versionCode `1`, versionName `0.1.0` (same as previous test APK).

`apksigner verify --print-certs` passes. Signing output matches the prior `stylemuse-visual-fixed-debug.apk` exactly. Android debug certificate SHA-256: `182bb6e1bfef791ef7d16567f4fcdd855aac6b90c59c28e41d5d0e080bd5eddd`.

Final exact artifact installed over the existing emulator app using `adb install --no-streaming -r`: **Success** (`phone-final3-install.log`). Existing local wardrobe item remained in persisted `app_flutter/closet.json` and visible in refreshed wardrobe UI (`phone-final3-wardrobe.xml/png`). The existing item is a prior emulator screenshot fixture, not proof of garment recognition. The final screenshot visibly preserves the light native UI. A transient System UI ANR after boot was dismissed with Wait; no app crash was inferred from that dialog.

Only this intended APK is published under a fresh unguessable path in the existing authorized `/srv/stylemuse` HTTPS root. Download returned HTTP 200, 195929442 bytes, full SHA-256 matching the local tested artifact (`phone-public-readback.txt`). The URL is public to anyone who knows it; this is not authenticated distribution. Public artifact metadata is retained in `/opt/stylemuse-tooling/phone-artifact.json`.

## Explicit remaining limits

- Real Android phone and real Google account login were unavailable; production OAuth connection is **not fixed end-to-end** while the native route returns 404.
- On the earlier final2 emulator APK, native gallery opened and the recognizable red-shirt fixture was visually confirmed. Selecting it caused the SwiftShader emulator process to disappear, preventing crop/save/restart verification on-device in this session. Final3 exact APK upgrade/launch/persistence is verified, but its complete device gallery/crop/save flow is **not verified**. Widget tests cover that flow, not hardware/plugin acceptance.
- Final emulator was shut down with guest sync and reboot poweroff. No emulator was left intentionally running.
- This is debug-signed testing distribution, not a production Play release; package reservation/upload-key ownership remains unverified. Nonblocking share_plus/Kotlin forward-compatibility build warning remains.
- Historical inherited logs are preserved locally and in backup, not included wholesale in this commit. Pre-existing implementation cannot be claimed as newly test-first work; targeted socket and CTA RED/GREEN logs are retained separately.
