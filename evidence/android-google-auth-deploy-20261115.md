# Android Google auth — 15 Kasım 2026 güvenli API dağıtımı

## Sonuç ve açık engel

**404 düzeltildi; gerçek Google/Android girişinin uçtan uca çalıştığı doğrulanmadı.**

Önceki `stylemuse-api:pr13-4305273af756` image'ının gerçek `/app/app.py` dosyasında native route yoktu. Worktree `dc27f47e63e466a27d553843de1127de24832202` ise native route + Android azp allowlist ve salt-okunur operation recovery içeriyordu. Diğer üç çalışan üretim modülü (`store.py`, `providers.py`, `virtual_tryon.py`) branch ile byte-identical idi. Bu, endpoint adlandırma tahmini değil, gerçek image/source farkı ve eski kaynakta 404 veren test ile kanıtlandı.

Sadece test edilen `app.py`, mevcut image'ın üzerine eklendi; başka bağımlılık veya üretim modülü değiştirilmedi. Çalışan API image: `stylemuse-api:android-auth-dc27f47`; image ID `sha256:7d2c4d4ea3e9cadfb5c1fbc50cc98b07f69c6ae667444288b1be5e632d3d6022`. Image ve container revision label aynı tam `dc27f47...` SHA'sını gösteriyor. Dört çalışan modülün SHA-256 değerleri branch ile eşleşiyor.

**Eksik yapılandırma:** Çalışan ortamda ve mevcut Compose merged konfigürasyonunda `STYLEMUSE_GOOGLE_ANDROID_CLIENT_IDS` yok. Mevcut WEB client ID korunmuştur. Android client ID tahmin edilmedi, web ID allowlist'e kopyalanmadı, imza/azp/nonce/oturum/origin kontrolleri gevşetilmedi. Native route artık geçerli biçimli fakat bilerek geçersiz credential için 503 `google_android_not_configured`; boş gövde için 422 döndürüyor. Bu, giriş başarısı değildir.

## Testler

Kanıt kökü: `/opt/stylemuse-tooling/auth-deploy-20261115/`.

- Eski dağıtılmış kaynak üzerinde `test_android_auth.py`: 404 kaynaklı RED saklandı (`deployed-native-red.log`). Bu tur yeni auth uygulaması yazılmadı; zaten commit edilmiş uygulama test edilip dağıtıldı.
- Python **3.12.16**, mevcut runtime bağımlılıkları ve ayrı pytest image'ı; `--network none`, izole import DB/storage, production secret/data mount olmadan auth/session/OAuth/browser-binding regresyonları: **76 geçti** (`auth-regressions-green.log`). Google verifier kullanılan pozitif hesap testleri açıkça **fixture/mock**, gerçek hesap değildir.
- Tüm backend: **221 geçti, 19 başarısız, 2 atlandı** (`backend-full-final.log`). Gerçek eski `/app/app.py` + aynı testler/dependencies: **210 geçti, 30 başarısız, 2 atlandı** (`backend-live-baseline.log`). Branch'e özgü yeni başarısız test **yok**. Ortak 19 failure eski provider-credit/manual-credit beklentileri ve missing-mask fidelity testi; bu işte hesaplama/admission davranışı veya testler değiştirilmedi. Tam suite temizmiş gibi sunulmuyor. Bir AnyIO deprecation uyarısı var.
- Gerçek Chromium + yerel HTTPS/fixture sağlayıcı ile iki ayrı browser context: CHIPS, top-level Lax proof, forwarded launch/authorize/provider callback reddi, legitimate fixture login ve replay reddi **geçti** (`web-auth-final.log`). Bu, gerçek Google hesabı veya canlı web giriş kanıtı değildir. Fixture konsolunda eski HTML-as-JS hataları da saklandı.
- İlave eski `github-browser.test.cjs` ve `session-mobile.test.cjs` UI testleri sırasıyla gizli logout düğmesi ve filechooser timeout nedeniyle başarısız; bu tur frontend kaynağı değiştirilmedi. İlk denemede eksik Playwright, ilk container full-suite denemesinde TMPDIR izni harness hataları vardı; sonraki gerçek çalıştırmalar ayrı loglarda tutuldu.
- `flutter analyze`: **No issues found**. `flutter test`: **59 geçti** (`flutter-analyze.log`, `flutter-test.log`). Android/Flutter uygulama kaynağı değiştirilmedi; gereksiz yeni APK build edilmedi.

## Yedek, yalnız API dağıtımı ve doğrulama

Testlerden ve candidate build'den sonra, API boşta iken (guard idle, pending job 0) gerçek bind mount `/opt/stylemuse-ai/runtime/data/state.sqlite3` SQLite online backup API ile yedeklendi:

`/opt/stylemuse-tooling/auth-deploy-20261115/backup/state-predeploy.sqlite3`

Yedek `PRAGMA integrity_check=ok`; mode 0600 ve üst klasör 0700. Ortam/Compose dosyaları kısıtlı backup içinde; içerikleri çıktıya veya Git'e konmadı. Rollback image: `stylemuse-api:rollback-before-android-auth-20261115`. Orijinal Compose listesi ve fingerprint/table-hash manifesti private `backup-manifest.json` içinde. DB restore yapılmadı ve restore tatbikatı iddia edilmiyor.

Kalıcı image override: `/opt/stylemuse-ai/releases/android-auth-dc27f47/compose.image.json`. Gerçek Compose projesi `server`, service `api`; merged config'te yalnız image + revision label değişikliği doğrulandı. Çalıştırılan rollout `up -d --no-deps --no-build api` ile sınırlıydı. Project-wide down, diğer service restart veya proxy değişikliği yapılmadı.

`verification-final.json` tüm kontrolleri doğruluyor:

- Container **healthy**; loopback ve public HTTPS health **200**.
- Çalışan environment mapping, secret dosyasının bytes/uid/gid/mode bilgisi, mountlar, runtime user/command/healthcheck ve resource/security/logging ayarları aynı.
- **15 kalıcı SQLite tablosunun tüm satır hash'leri ve sayıları aynı**; live DB integrity `ok`.
- Önceden çalışan systemd service PID/start kimlikleri aynı; SciVora dahil ilişkisiz servisler değiştirilmedi.
- Local/public native negatif test sırası: yapılandırma eksik **503**, boş payload **422**, kötü Origin **403**, oturumsuz **401**.
- Public `/api/session` **200**, anonim `/api/account` **200**, geçersiz web Google credential **401**, anonim token request/confirm **403**. Anonim balance 0 gerçek hesap bakiyesi değildir.
- Ücretli detect/generate/try-on çağrısı yapılmadı. Mevcut `STYLEMUSE_ENABLED=true` ayarı değiştirilmedi. Restart process-local login oturumlarını düşürür; gerçek kullanıcı yeniden giriş yapmalıdır.

Public kanıt: `public-after-final.json`; local: `local-after-final.json`. API tabanı: `https://stylemuse-api.129.121.148.187.sslip.io`.

## Android artifact ve gerçek hesap için gereken adım

Android uygulaması değişmedi; aynı package/test-signature APK korunuyor:

- Package `com.stylemuse.ai`.
- Debug signing SHA-1 `08:EF:41:C0:C6:48:D9:F5:33:FF:CA:62:E1:3A:97:D5:FF:0E:EA:4B`.
- APK `/opt/stylemuse-tooling/artifacts/stylemuse-phone-fixes-20261115-debug.apk`.
- SHA-256 `eb49ea126c4ca9097b27fdb3a67434805642cc7cd1d0d8824cff89240445c73a`.
- Mevcut public APK yeniden indirildi: HTTP **200**, **195929442** bytes ve aynı checksum (`apk-readback.json`). Yeni dosya yayımlanmadı; önceki link geçerli.

Google Cloud Credentials sayfası Google login'e yönlendirdi. `browser_vault list` **boş** döndü. Yetkili gerçek test hesabı mevcut değildi; parola/2FA istenmedi veya tahmin edilmedi. Bu nedenle Cloud Console'daki mevcut Android OAuth kaydı, gerçek Android/web Google girişi, kullanıcı profili ve gerçek Stil Jetonu bakiyesi **doğrulanamadı**.

Gereken kullanıcı adımı: yetkili Google Cloud hesabına güvenli tarayıcı/vault üzerinden giriş imkânı sağlamak; mevcut OAuth projesindeki Android client kaydının `com.stylemuse.ai` ve yukarıdaki debug SHA-1 ile eşleşmesini doğrulamak (kayıt varsa yeniden oluşturmamak). Doğrulanmış Android client ID mevcut backend allowlist'ine güvenli şekilde alınmalı; sonrasında aynı APK ile gerçek hesap girişi, profil/bakiye ve gerçek web login regresyonu yapılmalı. Şifre, ID token veya 2FA kodu sohbete gönderilmemeli. Bu gate açılmadan “Google bağlantısı tamamen düzeltildi” denemez.
