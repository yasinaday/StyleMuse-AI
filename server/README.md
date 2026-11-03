# StyleMuse AI – güvenli API kurulum taslağı

Bu klasör VPS'ye kurulacak ayrı StyleMuse servisinin hazırlığıdır. SciVora servislerine dokunmayın.

## Gerekenler
- Replicate API token (sunucuda ortam değişkeni olarak; **GitHub'a koymayın**).
- HTTPS alan adı ve ters vekil (reverse proxy).
- Kimlik doğrulama, kullanıcı başına istek sınırı ve harcama limiti.
- Kıyafet tespiti ve segmentasyon için iki aşamalı model: giysi sınıfı/bölge tespiti, ardından maske çıkarma. SAM 2 tek başına giysi sınıflandırması yapmaz.

## Dağıtım durumu
Henüz dağıtılmadı. Mevcut SciVora MCP bağlantısı READ_ONLY; sunucuda komut çalıştırma yetkisi yok.

## Güvenlik
Tarayıcıdan Replicate API'ye gizli anahtar gönderilmez. Fotoğraflar kişisel veri içerebilir; yüklemeden önce açık kullanıcı onayı, silme/saklama süresi ve hata durumunda masraf kontrolü gerekir.

## Kabul testi
- Üst, pantolon/etek ve ayakkabı görselleri arka plan yazılarından ayrılmalı.
- Yanlış kırpma otomatik olarak kaydedilmemeli.
- Model başarısızlığında kullanıcıya yanıltıcı 'AI sonucu' gösterilmemeli.
- 10–20 fotoğraflık testten sonra ücretli servisi etkinleştirme kararı verilmeli.
