# Bağımsız salt-okunur backend incelemesi

## Karar
F02 backend değişikliği kapsamında somut engelleyici güvenlik/işlev hatası veya yeni regresyon bulunmadı. Bu kapsamlı güvenlik kabulü değildir: **security acceptance OPEN**. Üretim, ücretli sağlayıcı çağrısı, commit veya kaynak düzenlemesi yapılmadı.

## İncelenen snapshot
- Repo: /opt/stylemuse-security-fix; HEAD 04455df881a03cecf453b2bd01ec9a77d52daf75.
- HEAD karşılaştırması backend.diff; yeni test_image_security.py ayrıca snapshot dizininde korundu.
- server altındaki 25 Python/requirements/Dockerfile dosyası before-sha256.json ve after-sha256.json ile hash'lendi; bütün hash'ler aynı. Kaynak değişiklikleri yok. Testler yalnız scratch kopyalarında çalıştırıldı.

## Kontroller
- Üretim Python dosyalarında tam tarama: yalnız üç Image.open çağrısı mevcut.
- app.py:69–79: MIME/admission uzunluğu → katı base64 decode → ham byte sınırı → Image.open(formats=('PNG','JPEG')) → format/piksel sınırı → load; açık EXIF transpose satır 83'te, bu kontrollerden sonra.
- providers.py:148–160: orijinal URI prefix + encoded-length sınırı → katı decode → 20 MiB byte sınırı → PNG/JPEG allowlist → 1,048,576 piksel sınırı → load/convert.
- providers.py:337–344: SafeHTTP indirmesi (378–385 streaming 64 MiB sınırı), ilave bytes/64 MiB sınırı → PNG-only open → tam 768x1024 boyut kontrolü → load. JPEG/TIFF/GIF/BMP/XBM generated decoder olarak dispatch edilmez.
- Önemli garanti sınırı: byte kontrolleri open'dan öncedir, ancak piksel kontrolü doğal olarak header open'dan sonradır. JPEG açılırken Pillow iç EXIF ayrıştırması yapabilir; tüm EXIF ayrıştırmasının piksel sınırından sonra olduğu iddia edilemez. Güvence açık uygulama load/exif_transpose sırasıdır; dependency yaması da gereklidir.

## Pillow resmi kanıtı
Resmi GitHub advisory API'leri bağımsız tekrar alındı ve xbm.json/exif.json içine kaydedildi:
- GHSA-xgh8-jp6q-p5x8: affected <=12.3.0, patched 13.0.0.
- GHSA-wqgw-9xfh-qf2g: affected <=12.3.0, patched 13.0.0.
- Resmi PyPI JSON tekrar alındı: release.json, version 13.0.0, Python >=3.11. Requirements pin bu düzeltmelerle eşleşiyor.
- Kaynaklar: https://github.com/python-pillow/Pillow/security/advisories/GHSA-xgh8-jp6q-p5x8 ; https://github.com/python-pillow/Pillow/security/advisories/GHSA-wqgw-9xfh-qf2g ; https://pypi.org/pypi/Pillow/13.0.0/json
- Önceki cp312 wheel hash kanıtı incelendi; bu inceleme Python 3.12/Docker runtime çalıştırmadı. Yerel izole runtime Pillow=13.0.0, Python 3.14.

## Çalıştırılmış testler ve önceki kanıt
- test_image_security.py tamamen incelendi: 17 parametrik vaka; allowlist AST/dispatch, byte allocation/open sırası, piksel/load sırası, desteklenen formatlar, generated boyutlar ve inclusive limitler.
- Socket connect/connect_ex/create_connection/getaddrinfo kapalı runner; STYLEMUSE/provider/auth/mail env temizliği; scratch import DB/storage ve private-photo override; pytest plugin autoload kapalı. Runner çalıştırmadan önce incelendi.
- focused.log: 19 passed / 1 private-photo skipped (17 image-security + normalization).
- combined.log ve combined/results.xml: aynı candidate kopyasında **24 passed / 1 skipped**, exit 0. Önceki 19 geçişe beş bağımsız vaka eklendi: original/generated açık EXIF guard sırası + üç malformed input fail-closed vakası. Tekrarlanan focused sonuçlar toplam sayıya eklenmedi.
- backend-retry/REPORT.md, results-comparison.json ve baseline-fixedenv/full-final XML incelendi. XML failure ID kümeleri bağımsız karşılaştırıldı: her ikisi 19, yeni failure ID yok. Tam baseline/final suite burada yeniden çalıştırılmadı.
- Mevcut 19 hata (18 ödeme/credit sözleşmesi, 1 boş maske sözleşmesi) çözülmüş veya güvenli kabul edilmiş değildir; F02 parser diff'inden kaynaklı yeni hata kanıtı yoktur.

## Kalan sınırlar
Bu inceleme zararlı advisory payload, canlı DoS, production kurulu dependency, Python 3.12 container, bütün dependency CVE taraması veya frontend güvenlik kabulü değildir. Mevcut geniş kapsamlı açıklar ve deployment readiness ayrıdır. Saf malformed fixture testleri native parser fuzzing yerine geçmez. Yeni engelleyici bulgu yok; security acceptance OPEN kalır.
