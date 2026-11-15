# PR17 validation — 2026-11-15

Branch: fix/android-profile-and-restore. Native flutter analyze passed; full Flutter suite 63 passed. APK debug build passed. Existing secure session is restored on startup without creating network traffic on first launch. Widget tests cover profile/avatar restore, admin/normal menu differences, logout, and disabled token purchases. Injected tests do not establish real Google login.

Web targeted admin/backup tests: 12 passed. V1/V2 import, IndexedDB reload and V2 export exercised in offline Chromium. Existing five admin operations are wired; direct-call permission checks and session-change protection added. Final complete frontend suite: 101 tests, 43 passed, 58 failed, 0 cancelled, 0 skipped. Acceptance remains blocked. Failures classified in /opt/stylemuse-tooling/pr17-validation/web/FULL-SUITE-CLASSIFICATION.md; not all independently replayed against HEAD. No claim that every failure predates this patch.

Google login: no physical device attached, no real-account logcat available. API Android client allowlist is now populated; prior missing-config report is historical, not current root-cause proof. Actual current login error remains undiagnosed without device evidence. No auth-security checks weakened and no live deployment performed.

Emulator showed Discover and unauthenticated Profile. System UI ANR preceded launch; emulator later disconnected before completing requested screens. Avatar picker, both profile subpages, language dropdown, token dialog, real admin/normal accounts and authenticated force-stop/relaunch persistence are not device-verified.

APK: com.stylemuse.ai, versionCode 1, same debug certificate as previous phone-fixes APK (SHA256 182bb6e1bfef791ef7d16567f4fcdd855aac6b90c59c28e41d5d0e080bd5eddd). Built artifact SHA256 0cf4cf5cbdca181e2931eb4d8c8117a51af1576bca23c6f4f97657287d30696a. Public download HTTP200 and complete hash matched. Update compatibility with the user's installed copy is not device-tested. No production release signing.

Backups: five prior APK ZIP CRC checks and nine SQLite backup integrity checks passed; this is not Android user-data restore acceptance. Web release snapshots could not be reliably mapped to V1/V2 labels; backup-format compatibility tests are separate evidence.

Primary evidence directory: /opt/stylemuse-tooling/pr17-validation. Native final logs: final-analyze.log and final-test.log. Web full log: web/full-frontend-final-06.tap. Device limits: DEVICE-STATUS.txt. Auth/backup inventory: auth-inventory.txt. APK delivery metadata: delivery.json.
