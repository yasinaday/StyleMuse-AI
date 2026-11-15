# Flutter StyleMuse API entegrasyonu

## Dışa aktarılan arayüz (`lib/stylemuse_api.dart`)

- `SecureStore`: `Future<String?> read(String key)`, `Future<void> write(String key, String value)`, `Future<void> delete(String key)`. UI `flutter_secure_storage`/Android Keystore ile uygular. Oturum cookie'si, pending fotoğrafları ve kurtarılabilir sonuçlar buradadır; SharedPreferences uygun değildir.
- `StyleMuseApi(storage: store, transport: optionalTransport, baseUrl: optionalHttpsUri)`; varsayılan gerçek dart:io transport, web uygulamasıyla aynı API adresi/origin. `initialize()`, `account()`, `signInGoogle(String idToken)`, `logout()`. Otomatik POST tekrarı ve HTTP yönlendirmesi yoktur. ID token diske yazılmaz.
- `TokenWorkflowController(api: api, storage: store, requestId: optionalIdFactory)`: aşağıdaki metotlar `Future<Map<String,dynamic>?>` döndürür; JSON backend ile aynıdır. UI listener/ChangeNotifier bağlayıcısını kendisi sağlar.
  - `extract(String imageDataUri, {required confirm})` → `{job_id,items:[{id,category,preview,...quality}]}`. Bir fotoğraf: **1 Stil Jetonu**.
  - `enhance(String jobId, List<String> itemIds, {required confirm})` → `{items:[{id,image}]}`. Her parça: **2 Stil Jetonu**.
  - `tryOn(String personDataUri, String garmentDataUri, {required confirm})` → `{job_id,state:'pending'}`. **Tek parça**, 1 Stil Jetonu. Önceki taslakta list olarak belirtilen parametre artık String'dir.
  - `recover()` → yukarıdaki tamamlanmış sonuç veya tryon `{job_id,state:'pending'|'done'|'failed',image?}`. Her çağrı en fazla bir durum sorgusudur; UI yalnız aktif ekrandayken, üst üste bindirmeden yeniden çağırır. Ücretli isteği yeniden göndermez.
  - `void cancel()` → yerel devamı durdurur. Gönderilmiş sağlayıcı işi iptal edilmiş veya jeton iade edilmiş gibi gösterilmez; geç sonuç güvenli saklanır.
  - `Future<void> acknowledge()` → yalnız tamamlanmış pending kaydını siler. **Önce sonuç gardırop/kombin deposuna kaydedilmeli**, sonra acknowledge çağrılmalı. Yeni iş önceki pending kaldırılana kadar engellenir.
  - `pending` → o instance'ın son yüklediği pending snapshot; başlangıçta diski okumak için `recover()` gerekir.
- `confirm`: yalnız `Future<bool> Function(int tokens)`. Onay penceresi jeton sayısını gösterir; USD, sağlayıcı kredi verisi veya sunucu fiyat alanlarını göstermez. Backend quote alanları adapter içinde korunur.
- `StyleMuseApiException.code`: `sign_in_required`, `pending_account_mismatch`, `pending_operation_requires_recovery`, `operation_in_progress`, `token_quote_mismatch` veya sunucu hata kodu. Ağ/timeout hataları otomatik retry edilmez. Belirsiz, bulunamayan veya tamamlanmamış detect/generate kayıtları fail-closed kalır; otomatik yeniden ödeme yoktur.

Girdi PNG/JPEG data URI (`data:image/png;base64,...`); bytes için `base64Encode`. Tryon sonucu HTTPS resim URL'sidir. Sonraki giydirme adımına URL değil, indirilip PNG/JPEG data URI'ye dönüştürülmüş resim verilmelidir. Çok parçalı kombin UI tarafından parça başına sırayla orkestre edilir; adapter sahte kompozit üretmez.

## Backend sözleşmesi (15 Kasım 2026 API-only dağıtımı)

Dağıtılan API kaynak revizyonu: `dc27f47e63e466a27d553843de1127de24832202`.
Aşağıdaki endpointler artık üretimde mevcut; gerçek Android OAuth hazırlığı ise tamamlanmış değildir.
Ayrıntılı kanıt: `evidence/android-google-auth-deploy-20261115.md`.

- `POST /api/auth/google/android {credential}`: mevcut oturum+exact origin kontrolü; Google `verify_oauth2_token` ile WEB audience/signature/issuer/expiry; Android `azp` allowlist, verified email ve `sub`. Native tokena web GIS nonce zorlanmaz; `/api/auth/google` nonce zorunluluğu aynen kalır.
- Yeni env `STYLEMUSE_GOOGLE_ANDROID_CLIENT_IDS`: virgülle ayrılan izinli Android OAuth client ID'leri. Eksikse verifier ağına çıkmadan 503. Web audience mevcut `STYLEMUSE_GOOGLE_CLIENT_ID`.
- `POST /api/operations/recover`: yalnız owner-bound okuma; rezervasyon/provider çağrısı yok.
  - `{action:'detect',request_id}` → `{state:'done',result}` veya ambiguous.
  - `{action:'generate',job_id,item_ids}` → tüm seçilen claims done ise `{state:'done',result}`, aksi ambiguous.
  - `{action:'tryon',request_id}` → original request'e bağlı job; başka kullanıcının veya başka pending işin sonucuna eşleşmez. Pending job TTL dolsa bile mevcut tryon status davranışıyla uyumlu kurtarılır.
- Native endpointin önceki 404 hatası, test edilen worktree değişikliklerini içermeyen eski API image'ından kaynaklanıyordu. Artık boş gövde 422; geçersiz credential + anonim oturum 503 `google_android_not_configured` döner. Android allowlist hâlâ eksik; bu, başarılı giriş değildir. Ücretli inference ve gerçek hesap çağrısı yapılmadı.

## Android OAuth hazır olma durumu

Salt-okunur yerel incelemede `/opt/stylemuse-ai/secrets/runtime.env` içinde web Google client ID mevcut; Android allowlist yok. Hiçbir değer/secret yazdırılmadı veya değiştirilmedi. Android application ID: `com.stylemuse.ai`.
Gerekenler: aynı Google Cloud projesinde bu package adına Android OAuth client kaydını doğrulamak; debug cihaz denemesi için debug SHA-1 `08:EF:41:C0:C6:48:D9:F5:33:FF:CA:62:E1:3A:97:D5:FF:0E:EA:4B`, üretimde Play App Signing sertifikası SHA-1 (upload sertifikası farklı olabilir); UI Google SDK `serverClientId` için mevcut WEB client ID; backend Android client allowlist. Endpoint dağıtımı tamamlandı. Cloud Console Google giriş sayfasına yönlendirdi ve browser vault kayıtlı hesap döndürmedi; mevcut Android OAuth kaydı ve gerçek test hesabı doğrulanamadı. Client ID tahmin edilmedi; web client ID Android allowlist'e kopyalanmadı.
UI bağımlılıkları: `google_sign_in`, `flutter_secure_storage`. Adapter için HTTP paketi gerekmez. Android secure-storage yedekleme politikasını UI/tooling sahibi ayrıca ayarlamalı.

## Test/evidence

`test/stylemuse_api_test.dart`: açıkça enjekte edilen FakeTransport ve MemorySecureStore; gerçek API/Google/ücretli inference yok. Dikey özellik dilimleri sırayla RED→GREEN çalıştırıldı; yeni Dart public sembolleri ilk RED'de eksik-sembol derleme hatası verdi, cancellation/account-isolation/response-loss mevcut-sembol dilimlerinde assertion RED'leri saklandı. `api-10-red.log` test fixture double-complete hatasıydı; geçerli RED `api-10b-red.log`.
Backend yeni testleri: `server/test_android_auth.py`; Google verifier mocked; yerel TestClient ve izole SQLite. İlk Android auth testinin RED 404 çıktısı terminalde gözlendi; diğer RED/GREEN kayıtları evidence altında.
Final kapsam ve baseline karşılaştırması `evidence/api-acceptance.md` dosyasında.
