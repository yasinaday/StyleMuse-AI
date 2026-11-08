# StyleMuse: offline garment integrity acceptance

## Outcome

- Fixed order-dependent duplicate selection: near-identical masks now resolve by detector confidence instead of prompt order.
- A larger detected jumpsuit/dress suppresses a contained trousers/skirt hypothesis only when it covers at least 90% of the lower-body mask and has at least 1.25x its area. Independent pants, overlapping jacket/top layers and left/right shoes remain separate. Masks are not subtracted or repainted.
- `pants` is accepted as an alias of `trousers`.
- fal prompt preserves open fronts, zipper position, pockets, original texture and visible markings; disallows invented labels, lining, accessories and hidden decoration. Request fields, safety checker, model and submission guards are unchanged.
- Review UI retains the original cutout and full source photo alongside generated results, gives an explicit quality checklist and accept/reject controls, and saves only selected, accepted, safely encoded generated images. Pending/rejected outputs cannot be saved. Fixed mobile stage overflow discovered by real pointer interaction.

## Final verification

Working directory: `/opt/stylemuse-ai-integration`.

- `15-backend-final.log`: **32 passed**, **2 subtests passed**, 73 dependency deprecation warnings, 3.16s. Command: `/opt/stylemuse-ai/integration-venv/bin/python` invoking `pytest.main(['server','-q'])` with `socket.socket.connect` and `connect_ex` replaced by a hard failure. This prevents real provider connections during the complete backend run.
- `16-frontend-final.log`: **11 passed**, **0 failed**, 2586.638465ms. Command: `node --test tests/frontend/*.test.cjs`. Includes 9 VM integration tests and 2 real headless Chromium DOM tests, 375x812 touch/mobile and 1280x812 desktop. External requests are aborted, except intercepted `fixture.invalid` responses; actual HTTP is loopback only. Tests exercise original upload, cost cancellation/confirmation, selected-only generation, retained original preview, reject/accept, explicit save, session-only token, console errors and horizontal overflow.
- Local private screenshots (not committed): `tests/frontend/evidence/review-375.png`, `tests/frontend/evidence/review-1280.png`.
- `security-review.json`: developer static review, protected file hashes unchanged, source-only `git diff --check` clean (retained raw RED/iteration logs contain trailing whitespace), no matches for checked private-key/provider/GitHub-token patterns. This is not independent security approval or a guarantee that a regex finds every secret.

## Fixture provenance

`fixture-manifest.json` records SHA-256, size, and image dimensions for existing read-only artifacts under `/opt/stylemuse-ai`:

- `test-photo.jpg`, original upload reused in the browser.
- `approved-four-test/results-0.json` through `results-3.json`, historical SAM masks replayed by the retained backend regression; jacket, jumpsuit, bag and two shoes.
- `approved-four-test/bordo-canta.png`, original mask preview used in browser replay.
- `final-four-products/products/bordo-canta.png`, historical generated output replayed as the browser generation response. Other retained product images are inventoried only, not claimed as newly evaluated.
- `model-schema-current.json`, pinned schema snapshot used by MockTransport contract tests.

New jumpsuit-vs-contained-pants, dress, jacket, trousers, bag and shoes coverage uses explicitly synthetic 12x16 masks. This tests postprocessing, not SAM semantic accuracy. The historical pixels are never presented as new model output. Private photos and masks remain outside Git. Browser fixture root can be overridden using `STYLEMUSE_FIXTURE_ROOT`; existing backend tests retain their prior `/opt/stylemuse-ai` fixture paths.

## Root cause and development evidence

Original extraction deduplicated immediately in category iteration order and only by IoU. A partial pants hypothesis and a larger complete jumpsuit can have low IoU despite the former being contained; both survived, while near-identical later higher-confidence hypotheses were discarded. Candidate collection and whole-garment containment resolution address these deterministic failures without damaging overlap pixels.

`01-red.log` contains three expected feature assertion failures before provider changes. These initial behaviors were grouped rather than strict one-at-a-time vertical TDD; do not describe this as perfect strict TDD compliance. `03-ui-red.log` records missing acceptance gate failure before UI implementation. `09-alias-red.log` and `14-markings-red.log` precede the alias/visible-marking fixes. Further overlap/independent-item tests are regression coverage, not additional RED evidence. Earlier failed iterations are preserved: `06-mobile.log` exposed the stage overflow, `07-frontend-final.log` is a repaired fixture-edit syntax error. Only logs 15 and 16 are final-source acceptance evidence.

## Limits / closed gates

- No paid API calls, new model inference, billing checks or real-model before/after quality claims. Prompt quality and SAM accuracy remain unvalidated. Missing jumpsuit candidates cannot be recovered by this geometry heuristic; unusual real layering can still require manual inspection/cropping.
- No real dress or independent-pants photo was available in the reused set; those categories are synthetic-mask coverage.
- Flutter SDK is absent (`security-review.json`: `flutter_sdk: null`); native Flutter tests/build were not run. Mobile validation is actual Chromium touch emulation, not Android/iOS or native Flutter. `lib/main.dart` remains unchanged.
- 73 warnings originate in the existing Python 3.14/FastAPI/Starlette dependency environment; no failing final tests.
- Production activation, environment, app/store budget and one-shot guards remain unchanged, default inference disabled. No service restart, deployment or push. This is configuration preservation, not a fresh live runtime health attestation. SciVora was not accessed or modified.
