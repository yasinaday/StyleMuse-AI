# StyleMuse AI — F01/F02 düzeltme raporu

Durum: GÜVENLİK KABULÜ OPEN. Merge, canlı dağıtım ve ücretli sağlayıcı aktivasyonu yapılmadı.
Başlangıç main: 04455df881a03cecf453b2bd01ec9a77d52daf75.
Dal: fix/security-backup-images-pillow.

## Frontend
Yedekten gelen görseller HTML src metin birleştirmesinden çıkarıldı; doğrulanmış görseller DOM img.src ile atanıyor. Kayıtlı kombin, dolap, öneri ve giydirme seçim yolları incelendi. Eski yedeklerin string ID düzenleme/silme/seçim handlerları DOM closure kullanıyor. Offline harness greedy script ayrıştırması düzeltildi.

Parent son birleşik frontend koşusu: 32 test, 10 başarılı / aynı 22 mevcut başarısız. Kanıt: /root/.hermes/cache/scratch/stylemuse-security-fix/parent-frontend-final.tap. Son yeni regresyon koşusu: 7/7 başarılı. Gerçek Chromium/IndexedDB: v1/v2 restore/reload, görsel zoom, string-ID edit/select/remove ve kalıcı silme; geçersiz restore mevcut dolabı değiştirmiyor; XSS olay özniteliği oluşmuyor.
Mevcut seçili beş dosyalık suite parser düzeltildikten sonra 25 sonuç: 3 başarılı, 22 başarısız. HEAD uygulaması + düzeltilmiş parser aynı 22 başarısızlığı veriyor. String-ID onarımı için ayrıca seçili koşu önce/sonra 12 sonuç: 2 başarılı, 10 başarısız, aynı failure kimlikleri. Bu ayrı koşular toplanmadı. Eski saveVirtualTryOn/saveCombo/save-button DOM beklentileri, eksik stub yöntemleri ve eski onay/politika beklentileri korunup raporlandı, güvenlik assertionları zayıflatılmadı.

## Backend ve oturum/yetki
Yeni image-security: 17/17 başarılı.
Son tam backend JUnit: 242 sonuç, 222 başarılı / 19 başarısız / 1 atlandı / 0 error. Aynı bağımlılık ortamında baseline: 225 sonuç, 205/19/1/0. Yeni failure kimliği: 0.
Alt test sayımı dahil JUnit toplamlarıdır; benzersiz üst-seviye testcase final 230 (210 başarılı/19 başarısız/1 atlandı), baseline 213 (193/19/1). Konsol parent/subtest sayıları bunlarla toplanmaz.
Ayrı parent oturum/OAuth/browser-binding/owner-budget koşusu: 72/72 başarılı, tam suite üzerine eklenmez.

## Kalanlar
Genel güvenlik kabulü verilmedi; diğer audit bulguları bu PR kapsamı dışında. Tam eski suite yeşil değil. Özel fotoğraf testi yetkilendirilmiş fixture olmadığından atlandı. Gerçek OAuth, ücretli sağlayıcı fidelity ve canlı hizmet test edilmedi. Docker/Python 3.12 runtime çalıştırılmadı; CPython 3.12 wheel indirimi/hash ve gereksinim uyumu doğrulandı. Backend çalıştırması Python 3.14.7 üzerinde. İlk parent auth denemesi yanlış venv nedeniyle pytest import edemedi; ikinci izole koşu 72/72 geçti, ilk log korundu.

## Kanıt kökü
/root/.hermes/cache/scratch/stylemuse-security-fix/
Frontend: frontend/, frontend-fix2-20261114T180405/; review: frontend-review/, frontend-review2/.
Backend: backend-retry/; review: backend-review/.
Kaynaklar canlı servis ağacı yerine /opt/stylemuse-security-fix ayrı git worktree üzerinde değiştirildi; integration çalışma kopyası korunmuştur.

## Backend ayrıntıları ve her mevcut başarısız test

# Backend image security implementation evidence

Security acceptance: OPEN. No commit, push, deployment, provider invocation or production DB/key/environment modification. Frontend sibling files were not edited by this agent.

## Changes
- server/app.py: explicit PNG/JPEG decoder allowlist; existing raw-byte and pixel checks remain before application load/EXIF normalization.
- server/providers.py: PNG/JPEG original allowlist, encoded-length admission before base64 allocation, generated PNG-only allowlist and explicit 64 MiB decoded-response bound before Image.open. Existing original 20 MiB / 1,048,576-pixel and generated 768x1024 checks retained.
- server/requirements.txt: Pillow==13.0.0.
- server/test_image_security.py: 17 harmless synthetic security regressions. Four vertical RED/GREEN slices retained in red1..4.log and green1..4.log; remaining assertions are regression/previous-behavior coverage, not claimed as new RED cycles.

## Official advisory/release verification
- https://github.com/python-pillow/Pillow/security/advisories/GHSA-xgh8-jp6q-p5x8
- https://github.com/python-pillow/Pillow/security/advisories/GHSA-wqgw-9xfh-qf2g
- Both official repository advisory API responses specify affected <=12.3.0, patched 13.0.0. Raw responses retained as GHSA-*.json.
- https://pypi.org/pypi/Pillow/13.0.0/json
- https://pypi.org/project/pillow/13.0.0/
- https://github.com/python-pillow/Pillow/releases/tag/13.0.0
- Release is published, requires Python >=3.11 (Dockerfile uses 3.12). CPython 3.12 Linux x86_64 wheel was actually downloaded and SHA256 matched PyPI metadata. Runtime tests used isolated scratch venv, Python 3.14.7/Pillow 13.0.0; Python 3.12 runtime was not executed. pip check passed.
- Important boundary: Pillow JPEG may parse EXIF inside Image.open before returning dimensions. The patched upstream IFD bound addresses that implicit parsing; application pixel checks precede explicit load/exif_transpose, not all internal JPEG metadata parsing. No malicious advisory payload or live DoS was run.

## Isolation and counts
Audit full-offline-runner.py was inspected. run.py copies server into unique scratch directories; clears STYLEMUSE/provider/auth/mail environment names; sets import DB/storage/private-photo override and pytest basetemp to scratch; blocks socket connect/connect_ex/create_connection/getaddrinfo; disables external pytest autoload. All provider transports in the new tests are in-memory MockTransport.
Baseline-fixedenv and full-final use the same isolated installed dependencies and Pillow 13.0.0. Baseline server snapshot predates these server edits.
- Baseline JUnit report: 225 outcomes, 205 pass / 19 fail / 1 skip / 0 error.
- Final JUnit report: 242 outcomes, 222 pass / 19 fail / 1 skip / 0 error.
- Unique top-level JUnit testcases: baseline 213 (193 pass/19 fail/1 skip), final 230 (210 pass/19 fail/1 skip). Pytest 9 counts unittest subtests separately in suite totals; its console says baseline 194 passed plus 11 subtests passed, final 211 passed plus 11 subtests passed. A parent unittest test can be counted as passed while a nested subtest fails; do not add console parent counts to top-level XML counts.
- Added image-security cases: 17/17 pass. Focused security+normalization: 19 pass/1 private-photo skip.
- New failures versus same-env baseline: 0. Unchanged existing failures: 19 (18 balance/manual-gate contract expectations + 1 mask-rejection expectation). No baseline policy was changed and no failure was suppressed.

## Individual existing balance/manual contract failures
- test_budget_accounting::test_real_unknown_credit_blocks_before_reservation_or_job
- test_manual_credit::test_manual_fallback_quote_discloses_risk_and_preserves_single_use
- test_manual_credit::test_quote_binds_manual_snapshot_and_refresh_does_not_reauthorize_old_quote[False]
- test_manual_credit::test_quote_binds_manual_snapshot_and_refresh_does_not_reauthorize_old_quote[True]
- test_manual_credit::test_manual_evidence_fails_closed_without_any_job_or_provider_submission[missing]
- test_manual_credit::test_manual_evidence_fails_closed_without_any_job_or_provider_submission[wrong_account]
- test_manual_credit::test_manual_evidence_fails_closed_without_any_job_or_provider_submission[expired]
- test_manual_credit::test_manual_evidence_fails_closed_without_any_job_or_provider_submission[insufficient]
- test_manual_credit::test_manual_evidence_fails_closed_without_any_job_or_provider_submission[identity_failure]
- test_paid_quotes::test_unverified_or_insufficient_credit_blocks_quote_and_submission[None]
- test_paid_quotes::test_unverified_or_insufficient_credit_blocks_quote_and_submission[0]
- test_paid_quotes::test_unverified_or_insufficient_credit_blocks_quote_and_submission[0.049]
- test_paid_quotes::test_unverified_or_insufficient_credit_blocks_quote_and_submission[nan]
- test_paid_quotes::test_unverified_or_insufficient_credit_blocks_quote_and_submission[inf]
- test_paid_quotes::test_unverified_or_insufficient_credit_blocks_quote_and_submission[True]
- test_paid_quotes::test_unverified_or_insufficient_credit_blocks_quote_and_submission[10]
- test_paid_quotes::test_generation_rechecks_real_credit_before_each_paid_submission
- test_virtual_tryon::test_tampering_and_credit_recheck_make_no_submission[balance]

## Existing mask failure
- test_provider_fidelity.FidelityTests::test_missing_or_empty_mask_is_explicitly_rejected
- Empty mask returns no extracted item instead of raising expected ProviderError; unchanged and out of image parser scope.

## Issues / limitations
- Installing old Pillow 11.2.1 into Python 3.14 failed building its unsupported source distribution; retained install-baseline.log and install-attempt2.log. No production environment was modified. Isolated installation of fixed Pillow and all pinned server requirements succeeded.
- An initial venv baseline could not import pytest after that failed install; retained baseline.log. The completed baseline-fixedenv/full-final runs replace that invalid setup attempt.
- web_extract backend was search-only, and browser extraction timed out. Official GitHub advisory/release APIs and PyPI JSON retrieval succeeded directly over HTTPS; raw authoritative responses and verified wheel retained.
- Existing dependency deprecation warnings remain (3279 warnings in each full run).
- Independent security review, Docker/Python 3.12 execution, broader audit findings and live readiness remain OPEN.

## Evidence
- full-final.log, full-final/results.xml
- baseline-fixedenv.log, baseline-fixedenv/results.xml
- results-comparison.json (individual messages + exact failure-set comparison)
- red1..4.log, green1..4.log, focused-final.log
- run.py, run-baseline.py (offline runners)
- official advisory JSONs, pillow-release.json, official-release-tag.json, cp312-wheel-verification.json
- final-source-sha256.json and evidence-sha256.json
