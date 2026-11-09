# OAuth browser binding security acceptance

Reviewed backend SHA-256: a0a623e599d5421e4f3d902dc93df7923687629dc51e1ed5414d43a11a487b35
Reviewed frontend SHA-256: 384cc82fd6489175ae1e113aedb9e231f69730e9d0c1e3440e73d8e58b30b48d

Scope: only StyleMuse OAuth browser binding and related frontend navigation/tests/docs. No inference activation, paid request, credential rotation, database migration, or SciVora change.

Final automated acceptance:
- 104 backend tests and 2 nested subtests passed (26-final-backend.log).
- 21 frontend tests passed (27-final-frontend.log).
- Real Chromium, two isolated browser contexts, three local HTTPS sites: real CHIPS session cookie plus independent top-level Lax proof.
- Forwarded launch handoff rejected. Forwarded authorize URL tested before consumption and rejected. Forwarded fixture provider URL followed by owner consent rejected; neither browser gains auth from that flow. Original pending attempt still succeeds with a one-use fixture code/PKCE; callback replay rejected. No detect/generate requests.
- State expiry, provider denial/failure, wrong identity, logout, newer-start supersession during exchange and expiry during exchange covered.
- Fresh-context same-model independent reviewer accepted the final hashes, reran 40 existing OAuth tests and 5 separate in-memory adversarial scenarios. This is not independent-provider/model approval.

Retained RED/GREEN evidence includes initial forwarded-link reproduction and later reviewer-driven transaction isolation, supersession and post-I/O deadline fixes. Historical browser timeout/debug failures are retained locally; final browser suite passes. The browser test time budget was increased from 60 to 180 seconds for the multi-navigation suite; assertions were not removed. Transient UI status polling was replaced by the actual handoff response assertion. Old VM test harness was updated for window/event APIs and the new launch contract.

Limits: provider consent and token exchange use an explicitly local fixture. No real owner GitHub login or physical phone acceptance is claimed. Python 3.14 test environment emits upstream deprecation warnings; production image remains Python 3.12.

Preservation: consistent SQLite online backup and private runtime snapshot retained outside git at /opt/stylemuse-ai/oauth-security-20261109T064527Z. Before deployment all live database table hashes and full container environment hash match baseline. Existing store.py and providers.py match the running container. Reviewer pytest import initialized the host default /var/lib/stylemuse/state.sqlite; this is NOT the production database (/opt/stylemuse-ai/runtime/data/state.sqlite3), whose unchanged table hashes were verified afterward. Keep test imports pointed at isolated paths in future.

Deployment and post-deployment verification are recorded in the private runtime evidence directory; never commit runtime environment snapshots, databases, test TLS keys or credentials.
