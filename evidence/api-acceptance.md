# API adapter / token controller kabul kaydı

## Sonuç

- Flutter API/controller test dosyası: **14 test PASS**, 0 fail (`api-flutter-final.log`). HTTP cevapları açık DI FakeTransport; disk yerine MemorySecureStore; canlı ücretli çağrı yok.
- Dart targeted analyze: **No issues found** (`api-analyze-final.log`).
- Yeni Android auth/recovery backend dosyası: **11 pytest case PASS** (70-pass targeted koşusunun içinde).
- İlgili auth/session/OAuth/enhancement regression seçimi: **70 passed** (`api-backend-config-green.log`). Enhancement wrapper içeride ayrı izole suite çalıştırır; 70 sayısı üst-seviye pytest sayımıdır.
- Tam server suite: **224 passed, 19 failed, 11 subtests passed** (`api-backend-final.log`). Tam suite yeşil DEĞİL.
- Aynı ortamda değişmemiş HEAD `git archive` baseline: **213 passed, aynı 19 failed, 11 subtests passed** (`api-backend-baseline.log`). Fail node adları normalize edilip programatik karşılaştırıldı: iki tarafta 19, tamamen aynı; yeni failure yok. Önceden var olan credit/manual-credit/provider-fidelity test uyumsuzluklarına kapsam dışı müdahale edilmedi.
- Python 3.14 / Starlette / FastAPI dependency deprecation warnings mevcut; uygulama hata çıktısı gibi gizlenmedi.

## Değişen sahipli dosyalar

`lib/stylemuse_api.dart`, `test/stylemuse_api_test.dart`, `server/app.py`, `server/test_android_auth.py`, `docs/flutter-api-interface.md`, `evidence/api-*`.
`evidence/ui-api-integration.txt` karşı ajana somut imzalarla güncellendi; UI ortak notu olarak commit'e alınmadı. main.dart, pubspec, android kaynakları değiştirilmedi.

## Emniyet / hazır olma

- Cookie ve pending fotoğraf/sonuçlar zorunlu `SecureStore` üzerinden; UI `flutter_secure_storage` implementation sağlar. Google ID token saklanmaz. Pending owner Google subject'e bağlanır; farklı kullanıcı cached sonucu recover edemez.
- Onay callback'i yalnız jeton sayısı alır: detect 1/photo, enhance 2/item, tryon 1/item. Onaysız/quote mismatch/storage failure/cancel durumları ücretli POST'u engeller.
- Cancel sunucu işi iptal/refund anlamına gelmez. Başlamış işin geç cevabı kalıcı saklanır; UI devamı bastırılır.
- Restart recovery read-only endpoint/status kullanır, submit/quote tekrarına gitmez. Done sonucu acknowledge edilene kadar korunur. Backend gerçekten belirsiz/başarısız işi güvenle sorgulayamadığında fail-closed kalır; otomatik yeni ödeme yoktur.
- Yeni Android login ve recovery endpointleri yalnız worktree'de. Deploy yapılmadı, servis/proxy/production secret değiştirilmedi.
- Yerel production runtime config'te WEB OAuth client ID var; Android client allowlist yok. `com.stylemuse.ai` için Android OAuth client ve signing/Play App Signing SHA-1, WEB `serverClientId`, backend allowlist ve ayrıca onaylı deployment gerekir. Google Cloud Console kayıtları yerel incelemeyle doğrulanamaz.

## TDD kanıt notu

Özellikler tek tek RED→GREEN yapıldı. Yeni Dart sembolleri için ilk RED'ler eksik sembol derleme hatasıydı; bunlar assertion RED olarak etiketlenmez. Mevcut API üzerinde cancellation/account isolation/lost-response davranışları gerçek assertion RED→GREEN ile doğrulandı. Ek son dört test, zaten uygulanmış güvenlik davranışlarının regression kapsamıdır, yeni RED iddiası değildir. `api-10-red.log` fixture double-complete hatası, düzeltilmiş gerçek RED `api-10b-red.log`; her iki kayıt korundu. İlk backend Android endpoint RED 404 ve GREEN terminalde görüldü; takip eden backend dilimlerinin logları korundu.
