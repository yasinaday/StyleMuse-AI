# Historical StyleMuse API pilot notes

SUPERSEDED: these notes describe the earlier API, not the current deployment. See ACCEPTANCE.md for current endpoints, Docker/HTTPS deployment, tests and disabled production gate.

1. Use a separate directory/container from SciVora; do not restart existing services.
2. Choose and verify a Replicate model with a compatible image/prompt input schema and an output that actually segments garments. SAM 2 alone does not classify garments. The generic adapter is not production-ready until this validation.
3. Set REPLICATE_API_TOKEN and a random STYLEMUSE_ACCESS_TOKEN as server-only secrets; never commit them or embed in GitHub Pages.
4. Build in the server directory: docker build -t stylemuse-api .
5. Run behind an HTTPS reverse proxy with authentication, request-size limits, per-user quotas and cost monitoring. Bind the container to 127.0.0.1 only, not a public port.
6. GET /health reports whether credentials/model are configured. POST /v1/analyze accepts JSON {image: data:image/jpeg;base64,..., prompt: ...} with Authorization: Bearer <STYLEMUSE_ACCESS_TOKEN>.
7. A browser-facing production service requires a real login/session mechanism; a shared bearer token must not be baked into public JavaScript. This pilot endpoint is for authenticated private tests only.
8. The response is the raw model output, NOT a verified set of separated clothes. Add output normalization, polling for async predictions, garment category validation, segmentation compositing and user review before connecting the live UI.
9. The in-memory rate limit only works for a single worker; for public release add persistent/shared rate limiting and spending caps.

Status: code prepared, not deployed, no API calls or charges made.
