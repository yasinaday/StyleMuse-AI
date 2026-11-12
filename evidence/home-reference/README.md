# Home reference implementation

Source: `docs/design/stylemuse-home-reference.jpg`, supplied in main commit `2a870a6`.

Only the home composition, home header/dialogs and shared navigation illustrations were changed. Wardrobe, try-on, authentication, storage and paid-inference implementations remain unchanged, except that the global image zoom handler now ignores decorative home images so card-image taps navigate normally.

## Local assets

`assets/home/*.webp` were cropped from the supplied reference without an AI service:

- `model.webp`: model silhouette with feathered boundary/bottom.
- `wave.webp`: pink light wave, feathered at its edges.
- `separate.webp`, `tryon.webp`, `outfits.webp`, `wardrobe.webp`: illustration areas only, with no reference labels baked in.

The heading, descriptions, card surfaces, brush stroke, header, menu, PRO information dialog and navigation are real HTML/CSS/SVG controls. PRO has no existing subscription checkout, so it explains availability and links to existing profile/AI settings; it never starts a payment or inference.

## Verification

Run from repository root after installing the existing frontend Playwright dependency and its Chromium browser:

    node --test tests/frontend/home-reference.test.cjs

The test serves the actual repository page locally and opens Chromium at 360×700, 390×700 and 430×700. All external HTTPS traffic is blocked. It checks local illustration loading, horizontal overflow, card text clipping, navigation overlap, all four card routes (including the separation file chooser), all five navigation items, menu routing, PRO information/settings routing and profile routing. Card-image taps must not open the image zoom overlay. No page exceptions or paid API requests are allowed.

`mobile-*.png`: unmodified browser screenshots. `comparison-390.png`: reference scaled to 390 px on the left; browser screenshot on the right. The reference has no bottom navigation, so the requested navigation is an intentional addition. CSS typography, reconstructed background and feathered image extraction are not a pixel-identical reproduction of the raster reference.

`results.json`: mobile acceptance measurements.

## Existing regression failures

Four existing suites (`integration`, `paid-quotes`, `manual-credit`, `footwear`) were also executed against both untouched main `30b7b97` (which arrived while this work was in progress) and this rebased implementation: 27 tests each, 5 pass and 22 fail in both. The test-case outcome lists are identical. Existing failures include incomplete fake DOM methods (`el.remove`), expectations from older AI-review/cost copy, legacy storage assumptions and selected-generation workflow expectations. No out-of-scope backend/AI/test-harness rewrite was made to hide them.

`regression-summary.json` records every baseline/updated test-case outcome. This is home acceptance, not a claim that the complete application regression suite is green. Live paid inference, OAuth login and payment were intentionally not exercised.
