(() => {
 'use strict';
 const languages=['tr','en','de','ru','ar','fr','hi','zh','ja'];
 const phrases=`
Stil Jetonu Al|Buy Style Tokens|Style-Token kaufen|Купить стиль-токены|شراء رموز الأناقة|Acheter des jetons Style|स्टाइल टोकन खरीदें|购买风格点数|スタイルトークンを購入
Stil Profilim|My style profile|Mein Stilprofil|Мой стиль-профиль|ملف أسلوبي|Mon profil de style|मेरी शैली प्रोफ़ाइल|我的风格档案|スタイルプロフィール
Bilgilerim|My details|Meine Angaben|Мои данные|معلوماتي|Mes informations|मेरी जानकारी|我的信息|個人情報
Yönetici ayarları ve bildirimler|Admin settings and notifications|Admin-Einstellungen und Hinweise|Настройки и уведомления администратора|إعدادات المدير والإشعارات|Paramètres et notifications admin|व्यवस्थापक सेटिंग्स और सूचनाएँ|管理员设置和通知|管理者設定と通知
Ten rengi|Skin tone|Hautton|Тон кожи|لون البشرة|Teint|त्वचा का रंग|肤色|肌の色
Vücut tipi|Body shape|Körperform|Тип фигуры|شكل الجسم|Morphologie|शारीरिक बनावट|体型|体型
Boy (cm)|Height (cm)|Größe (cm)|Рост (см)|الطول (سم)|Taille (cm)|कद (सेमी)|身高（厘米）|身長（cm）
Kilo (kg)|Weight (kg)|Gewicht (kg)|Вес (кг)|الوزن (كغ)|Poids (kg)|वज़न (किग्रा)|体重（公斤）|体重（kg）
Beden|Clothing size|Kleidergröße|Размер одежды|مقاس الملابس|Taille de vêtement|कपड़ों का साइज़|服装尺码|服のサイズ
Ücretsiz plan|Free plan|Kostenloser Plan|Бесплатный план|الخطة المجانية|Offre gratuite|मुफ़्त प्लान|免费方案|無料プラン
Keşfet|Discover|Entdecken|Обзор|استكشاف|Découvrir|खोजें|探索|見つける
Giysiler|Clothes|Kleidung|Одежда|الملابس|Vêtements|कपड़े|服装|服
Kombinler|Outfits|Outfits|Образы|الإطلالات|Tenues|पहनावे|搭配|コーデ
Mankenim|My model|Mein Model|Моя модель|عارضتي|Mon modèle|मेरा मॉडल|我的模特|マイモデル
Profil|Profile|Profil|Профиль|الملف الشخصي|Profil|प्रोफ़ाइल|个人资料|プロフィール
Ayarlar|Settings|Einstellungen|Настройки|الإعدادات|Paramètres|सेटिंग्स|设置|設定
Uygulama dili|App language|App-Sprache|Язык приложения|لغة التطبيق|Langue de l’application|ऐप की भाषा|应用语言|アプリの言語
Stil Jetonu|Style Token|Style-Token|Стиль-токен|رمز الأناقة|Jeton Style|स्टाइल टोकन|风格点数|スタイルトークン
Uygulama ücretsiz. Yapay zekâ işlemleri jetonla kullanılır.|The app is free. AI actions use tokens.|Die App ist kostenlos. KI-Aktionen benötigen Token.|Приложение бесплатное. Для операций ИИ нужны токены.|التطبيق مجاني. تستخدم عمليات الذكاء الاصطناعي الرموز.|L’application est gratuite. Les actions IA utilisent des jetons.|ऐप मुफ़्त है। एआई कार्यों के लिए टोकन लगते हैं।|应用免费，AI 操作使用点数。|アプリは無料です。AI 機能にはトークンを使います。
1 jeton = 1 yapay zekâ işlemi|1 token = 1 AI action|1 Token = 1 KI-Aktion|1 токен = 1 операция ИИ|رمز واحد = عملية ذكاء اصطناعي واحدة|1 jeton = 1 action IA|1 टोकन = 1 एआई कार्य|1 点数 = 1 次 AI 操作|1 トークン = AI 操作 1 回
Jeton paketi seç|Choose a token pack|Tokenpaket wählen|Выберите пакет токенов|اختر باقة رموز|Choisir un lot de jetons|टोकन पैक चुनें|选择点数包|トークンパックを選択
1 jeton|1 token|1 Token|1 токен|رمز واحد|1 jeton|1 टोकन|1 点|1 トークン
10 jeton|10 tokens|10 Token|10 токенов|10 رموز|10 jetons|10 टोकन|10 点|10 トークン
50 jeton|50 tokens|50 Token|50 токенов|50 رمزًا|50 jetons|50 टोकन|50 点|50 トークン
100 jeton|100 tokens|100 Token|100 токенов|100 رمز|100 jetons|100 टोकन|100 点|100 トークン
200 jeton|200 tokens|200 Token|200 токенов|200 رمز|200 jetons|200 टोकन|200 点|200 トークン
/ jeton|/ token|/ Token|/ токен|/ رمز|/ jeton|/ टोकन|/ 点|/ トークン
En iyi teklif|Best offer|Bestes Angebot|Лучшее предложение|أفضل عرض|Meilleure offre|सबसे अच्छा ऑफ़र|最佳优惠|最もお得
25 jeton|25 tokens|25 Token|25 токенов|25 رمزًا|25 jetons|25 टोकन|25 点|25 トークン
Satın al|Buy|Kaufen|Купить|شراء|Acheter|खरीदें|购买|購入
Satın alma henüz kullanıma açık değil.|Purchases are not available yet.|Käufe sind noch nicht verfügbar.|Покупки пока недоступны.|الشراء غير متاح بعد.|Les achats ne sont pas encore disponibles.|खरीदारी अभी उपलब्ध नहीं है।|购买功能尚未开放。|購入はまだ利用できません。
Yapay Zekâ ile|With AI|Mit KI|С помощью ИИ|بالذكاء الاصطناعي|Avec l’IA|एआई के साथ|借助 AI|AI で
Stilini Keşfet|Find your style|Finde deinen Stil|Найдите свой стиль|اكتشف أسلوبك|Trouvez votre style|अपनी शैली खोजें|探索你的风格|自分のスタイルを見つける
Kıyafetlerini ayır, üzerinde dene,|Extract clothes, try them on,|Kleidung freistellen, anprobieren|Выделяйте одежду, примеряйте её|افصل الملابس وجرّبها،|Isolez les vêtements, essayez-les|कपड़े अलग करें, पहनकर देखें,|提取服装、试穿，|服を切り出し、試着して、
rahat kombinler oluştur.|and create easy outfits.|und Outfits zusammenstellen.|и создавайте образы.|ونسّق إطلالاتك.|et composez des tenues.|और पहनावे बनाएँ।|轻松搭配。|コーデを作りましょう。
Kıyafetleri Ayır|Extract Clothes|Kleidung freistellen|Выделить одежду|فصل الملابس|Isoler les vêtements|कपड़े अलग करें|提取服装|服を切り出す
Tek fotoğraftan|From one photo|Aus einem Foto|Из одного фото|من صورة واحدة|Depuis une photo|एक फ़ोटो से|从一张照片|1 枚の写真から
birden fazla ürün çıkar|extract multiple items|mehrere Teile extrahieren|выделите несколько вещей|استخرج عدة قطع|isolez plusieurs articles|कई कपड़े अलग करें|提取多件服装|複数の服を抽出
AI ile Giydir|AI Try-On|KI-Anprobe|Примерка с ИИ|تجربة الملابس بالذكاء الاصطناعي|Essayage IA|एआई से पहनाएँ|AI 试穿|AI 試着
Kıyafetleri üzerinde dene|Try on your clothes|Probiere deine Kleidung an|Примерьте одежду|جرّب ملابسك|Essayez vos vêtements|अपने कपड़े पहनकर देखें|试穿你的服装|服を試着する
Kombin Önerileri|Outfit Ideas|Outfit-Ideen|Идеи образов|اقتراحات الإطلالات|Idées de tenues|पहनावे के सुझाव|搭配灵感|コーデの提案
Tarzına uygun kombinler oluştur|Create outfits in your style|Stelle passende Outfits zusammen|Создавайте образы в своём стиле|نسّق إطلالات تناسب أسلوبك|Composez des tenues à votre style|अपनी शैली के पहनावे बनाएँ|创建适合你的搭配|好みに合うコーデを作る
Dolabını Oluştur|Build Your Wardrobe|Baue deinen Kleiderschrank auf|Соберите гардероб|أنشئ خزانتك|Créez votre dressing|अपनी अलमारी बनाएँ|建立衣橱|ワードローブを作る
Kendi kıyafet koleksiyonunu hazırla|Build your own clothing collection|Erstelle deine Kleidersammlung|Соберите свою коллекцию одежды|كوّن مجموعة ملابسك|Créez votre collection de vêtements|अपने कपड़ों का संग्रह बनाएँ|建立个人服装收藏|自分の服をまとめる
Dolabındaki parçaları düzenle ve yeni kıyafetler ekle.|Manage your wardrobe and add new clothes.|Verwalte deine Kleidung und füge neue Teile hinzu.|Управляйте гардеробом и добавляйте одежду.|رتّب خزانتك وأضف ملابس جديدة.|Gérez votre dressing et ajoutez des vêtements.|अलमारी सँभालें और नए कपड़े जोड़ें।|整理衣橱并添加新衣服。|服を整理して新しい服を追加します。
Dolaba Kıyafet Ekleme|Add Clothes|Kleidung hinzufügen|Добавить одежду|إضافة ملابس|Ajouter des vêtements|कपड़े जोड़ें|添加服装|服を追加
Üst giyim|Tops|Oberteile|Верх|ملابس علوية|Hauts|ऊपरी कपड़े|上装|トップス
Alt giyim|Bottoms|Unterteile|Низ|ملابس سفلية|Bas|निचले कपड़े|下装|ボトムス
Elbise|Dress|Kleid|Платье|فستان|Robe|ड्रेस|连衣裙|ワンピース
Çanta|Bag|Tasche|Сумка|حقيبة|Sac|बैग|包袋|バッグ
Dış giyim|Outerwear|Jacken & Mäntel|Верхняя одежда|ملابس خارجية|Vestes et manteaux|बाहरी कपड़े|外套|アウター
Aksesuar|Accessory|Accessoire|Аксессуар|إكسسوار|Accessoire|ऐक्सेसरी|配饰|アクセサリー
Diğer|Other|Sonstiges|Другое|أخرى|Autre|अन्य|其他|その他
Tümü|All|Alle|Все|الكل|Tous|सभी|全部|すべて
＋ Fotoğraf seç ve dolabıma ekle|＋ Choose a photo and add it|＋ Foto wählen und hinzufügen|＋ Выбрать и добавить фото|＋ اختر صورة وأضفها|＋ Choisir et ajouter une photo|＋ फ़ोटो चुनें और जोड़ें|＋ 选择照片并添加|＋ 写真を選んで追加
✦ Tek fotoğraftan birden fazla kıyafet|✦ Multiple items from one photo|✦ Mehrere Teile aus einem Foto|✦ Несколько вещей из одного фото|✦ عدة قطع من صورة واحدة|✦ Plusieurs vêtements sur une photo|✦ एक फ़ोटो से कई कपड़े|✦ 从一张照片提取多件服装|✦ 1 枚の写真から複数の服
✦ Yapay zekâ ile kıyafetleri ayır|✦ Extract clothes with AI|✦ Kleidung mit KI freistellen|✦ Выделить одежду с ИИ|✦ افصل الملابس بالذكاء الاصطناعي|✦ Isoler les vêtements avec l’IA|✦ एआई से कपड़े अलग करें|✦ 用 AI 提取服装|✦ AI で服を切り出す
AI ile analiz et|Analyze with AI|Mit KI analysieren|Анализировать с ИИ|حلّل بالذكاء الاصطناعي|Analyser avec l’IA|एआई से विश्लेषण करें|使用 AI 分析|AI で分析
Toplu ürün aktarımı|Bulk import|Sammelimport|Массовый импорт|استيراد جماعي|Import groupé|एक साथ आयात|批量导入|一括インポート
↓ Ürün paketini içe aktar|↓ Import wardrobe pack|↓ Kleidungspaket importieren|↓ Импортировать набор|↓ استورد مجموعة الملابس|↓ Importer un lot de vêtements|↓ कपड़ों का पैक आयात करें|↓ 导入服装包|↓ 服のパックをインポート
Dolabın seni bekliyor|Your wardrobe awaits|Dein Kleiderschrank wartet|Ваш гардероб ждёт|خزانتك تنتظرك|Votre dressing vous attend|आपकी अलमारी तैयार है|衣橱等你填满|ワードローブは空です
İlk parçanı ekleyerek başlayabilirsin.|Start by adding an item.|Füge zuerst ein Teil hinzu.|Начните с добавления вещи.|ابدأ بإضافة قطعة.|Commencez par ajouter un article.|पहला कपड़ा जोड़कर शुरू करें।|先添加一件服装。|最初の服を追加しましょう。
Günün planına ve tarzına göre bir kombin oluştur.|Build an outfit for your plans and style.|Erstelle ein Outfit für deinen Anlass und Stil.|Подберите образ под планы и стиль.|نسّق إطلالة تناسب خططك وأسلوبك.|Composez une tenue selon vos projets et votre style.|योजना और शैली के अनुसार पहनावा बनाएँ।|根据计划和风格创建搭配。|予定とスタイルに合わせてコーデを作ります。
Bugünkü planın|Today’s plans|Dein heutiger Anlass|Планы на сегодня|خطط اليوم|Vos projets du jour|आज की योजना|今日计划|今日の予定
Günlük|Everyday|Alltag|На каждый день|يومي|Quotidien|रोज़मर्रा|日常|日常
İş / Ofis|Work / Office|Arbeit / Büro|Работа / Офис|العمل / المكتب|Travail / Bureau|काम / दफ़्तर|工作 / 办公室|仕事・オフィス
Akşam yemeği|Dinner|Abendessen|Ужин|عشاء|Dîner|रात का खाना|晚餐|ディナー
Özel davet|Special event|Besonderer Anlass|Особый случай|مناسبة خاصة|Occasion spéciale|विशेष अवसर|特别场合|特別なイベント
Hangi tarz?|Which style?|Welcher Stil?|Какой стиль?|أي أسلوب؟|Quel style ?|कौन-सी शैली?|哪种风格？|どのスタイル？
Rahat ve şık|Casual chic|Lässig und schick|Повседневный шик|مريح وأنيق|Décontracté chic|आरामदायक और आकर्षक|休闲时尚|カジュアルシック
Minimal|Minimal|Minimalistisch|Минимализм|بسيط|Minimaliste|सादगीपूर्ण|极简|ミニマル
Romantik|Romantic|Romantisch|Романтический|رومانسي|Romantique|रोमांटिक|浪漫|ロマンティック
Modern klasik|Modern classic|Modern klassisch|Современная классика|كلاسيكي عصري|Classique moderne|आधुनिक क्लासिक|现代经典|モダンクラシック
Bana fikir ver ✦|Give me an idea ✦|Schlag mir etwas vor ✦|Предложить образ ✦|اقترح إطلالة ✦|Proposer une tenue ✦|सुझाव दें ✦|给我灵感 ✦|コーデを提案 ✦
✦ Senin kombin fikrin|✦ Your outfit idea|✦ Deine Outfit-Idee|✦ Ваш образ|✦ اقتراح إطلالتك|✦ Votre idée de tenue|✦ आपके पहनावे का सुझाव|✦ 你的搭配灵感|✦ あなたへのコーデ提案
Kaydettiğim kombinler|Saved outfits|Gespeicherte Outfits|Сохранённые образы|الإطلالات المحفوظة|Tenues enregistrées|सहेजे गए पहनावे|已保存的搭配|保存したコーデ
Dolabından seç, manken üzerinde dene.|Pick from your wardrobe and try it on your model.|Wähle Kleidung aus und probiere sie am Model an.|Выберите вещи и примерьте их на модели.|اختر من خزانتك وجرّب على العارضة.|Choisissez des vêtements et essayez-les sur votre modèle.|अलमारी से चुनें और मॉडल पर पहनाएँ।|从衣橱中挑选并在模特上试穿。|服を選んでモデルに試着します。
KOMBİN|OUTFIT|OUTFIT|ОБРАЗ|إطلالة|TENUE|पहनावा|搭配|コーデ
ÖNER|SUGGEST|VORSCHLAGEN|ПРЕДЛОЖИТЬ|اقترح|PROPOSER|सुझाएँ|推荐|提案
Temizle|Clear|Leeren|Очистить|مسح|Effacer|साफ़ करें|清空|クリア
Manken hazırlanıyor…|Preparing model…|Model wird vorbereitet…|Подготовка модели…|جارٍ تجهيز العارضة…|Préparation du modèle…|मॉडल तैयार हो रहा है…|正在准备模特…|モデルを準備中…
♡ Kombinimi kaydet|♡ Save my outfit|♡ Outfit speichern|♡ Сохранить образ|♡ احفظ إطلالتي|♡ Enregistrer ma tenue|♡ पहनावा सहेजें|♡ 保存我的搭配|♡ コーデを保存
＋ Kendi fotoğrafımı yükle|＋ Upload my photo|＋ Eigenes Foto hochladen|＋ Загрузить своё фото|＋ ارفع صورتي|＋ Importer ma photo|＋ अपनी फ़ोटो अपलोड करें|＋ 上传我的照片|＋ 自分の写真をアップロード
✦ Yapay zekâ ile gerçekçi giydir|✦ Try on with AI|✦ Mit KI anprobieren|✦ Примерить с ИИ|✦ جرّب بالذكاء الاصطناعي|✦ Essayer avec l’IA|✦ एआई से पहनाकर देखें|✦ 使用 AI 试穿|✦ AI で試着する
Dolabımdan seç|Choose from my wardrobe|Aus meinem Schrank wählen|Выбрать из гардероба|اختر من خزانتي|Choisir dans mon dressing|मेरी अलमारी से चुनें|从衣橱中选择|ワードローブから選ぶ
Tarz tercihlerini ve hesap ayarlarını yönet.|Manage style preferences and account settings.|Verwalte Stil- und Kontoeinstellungen.|Настройте стиль и параметры аккаунта.|أدر تفضيلات الأسلوب وإعدادات الحساب.|Gérez vos préférences et votre compte.|शैली और खाता सेटिंग्स सँभालें।|管理风格偏好和账户设置。|スタイルの好みとアカウント設定を管理します。
GitHub ile giriş yap|Sign in with GitHub|Mit GitHub anmelden|Войти через GitHub|تسجيل الدخول باستخدام GitHub|Se connecter avec GitHub|GitHub से साइन इन करें|使用 GitHub 登录|GitHub でログイン
GitHub çıkış|Sign out of GitHub|Von GitHub abmelden|Выйти из GitHub|تسجيل الخروج من GitHub|Se déconnecter de GitHub|GitHub से साइन आउट करें|退出 GitHub|GitHub からログアウト
Nasıl hitap edelim?|What should we call you?|Wie sollen wir dich nennen?|Как к вам обращаться?|بماذا نناديك؟|Comment vous appeler ?|हम आपको क्या बुलाएँ?|我们该如何称呼你？|お名前は？
Adın|Your name|Dein Name|Ваше имя|اسمك|Votre prénom|आपका नाम|你的名字|あなたの名前
En sevdiğin tarz|Favorite style|Lieblingsstil|Любимый стиль|أسلوبك المفضل|Style préféré|पसंदीदा शैली|最喜欢的风格|好きなスタイル
Stil özetim|My style summary|Meine Stilübersicht|Мой стиль|ملخص أسلوبي|Mon aperçu de style|मेरी शैली का सार|我的风格概览|スタイル概要
Verilerimi yedekle ↓|Back up my data ↓|Daten sichern ↓|Сохранить копию данных ↓|انسخ بياناتي احتياطيًا ↓|Sauvegarder mes données ↓|मेरे डेटा का बैकअप ↓|备份我的数据 ↓|データをバックアップ ↓
Kategori|Category|Kategorie|Категория|الفئة|Catégorie|श्रेणी|类别|カテゴリ
Fotoğrafı düzenle ✂|Edit photo ✂|Foto bearbeiten ✂|Редактировать фото ✂|عدّل الصورة ✂|Modifier la photo ✂|फ़ोटो संपादित करें ✂|编辑照片 ✂|写真を編集 ✂
Yakınlaştır|Zoom|Zoom|Масштаб|تكبير|Zoom|ज़ूम|缩放|拡大
Vazgeç|Cancel|Abbrechen|Отмена|إلغاء|Annuler|रद्द करें|取消|キャンセル
Kapat|Close|Schließen|Закрыть|إغلاق|Fermer|बंद करें|关闭|閉じる
Kırp ve kaydet ✓|Crop and save ✓|Zuschneiden und speichern ✓|Обрезать и сохранить ✓|اقتص واحفظ ✓|Recadrer et enregistrer ✓|काटें और सहेजें ✓|裁剪并保存 ✓|切り抜いて保存 ✓
✎ Düzenle|✎ Edit|✎ Bearbeiten|✎ Править|✎ تعديل|✎ Modifier|✎ संपादित करें|✎ 编辑|✎ 編集
Sil|Delete|Löschen|Удалить|حذف|Supprimer|हटाएँ|删除|削除
Kaydet|Save|Speichern|Сохранить|حفظ|Enregistrer|सहेजें|保存|保存
Bağlantı durumu|Connection status|Verbindungsstatus|Состояние подключения|حالة الاتصال|État de la connexion|कनेक्शन की स्थिति|连接状态|接続状態
Yeniden kontrol et|Check again|Erneut prüfen|Проверить снова|تحقق مجددًا|Vérifier à nouveau|फिर जाँचें|重新检查|再確認
Kombinin için kıyafet seç.|Choose clothes for your outfit.|Wähle Kleidung für dein Outfit.|Выберите одежду для образа.|اختر الملابس لإطلالتك.|Choisissez des vêtements pour votre tenue.|अपने पहनावे के लिए कपड़े चुनें।|为搭配挑选服装。|コーデに使う服を選びましょう。
Aynı giydirme işini kontrol et|Check the same try-on job|Dieselbe Anprobe prüfen|Проверить текущую примерку|تحقق من عملية التجربة الحالية|Vérifier le même essayage|उसी ट्राय-ऑन की स्थिति देखें|查看同一试穿任务|同じ試着処理を確認
Kombin hazır|Outfit ready|Outfit fertig|Образ готов|الإطلالة جاهزة|Tenue prête|पहनावा तैयार है|搭配已就绪|コーデができました
Giydirme durdu.|Try-on stopped.|Anprobe gestoppt.|Примерка остановлена.|توقفت تجربة الملابس.|L’essayage s’est arrêté.|ट्राय-ऑन रुक गया।|试穿已停止。|試着が停止しました。
Önceki işlem bekliyor.|A previous job is pending.|Ein früherer Vorgang ist noch offen.|Предыдущая задача ожидает завершения.|هناك عملية سابقة قيد الانتظار.|Une tâche précédente est en attente.|पिछला कार्य लंबित है।|之前的任务仍在等待。|前の処理が保留中です。
Dolabında kıyafet yok. Önce bir kıyafet ekle.|Your wardrobe is empty. Add a clothing item first.|Dein Schrank ist leer. Füge zuerst ein Kleidungsstück hinzu.|Гардероб пуст. Сначала добавьте одежду.|خزانتك فارغة. أضف قطعة ملابس أولًا.|Votre dressing est vide. Ajoutez d’abord un vêtement.|अलमारी खाली है। पहले एक कपड़ा जोड़ें।|衣橱为空，请先添加服装。|ワードローブは空です。先に服を追加してください。
Çanta veya aksesuar yok|No bag or accessory|Keine Tasche oder Accessoires|Нет сумки или аксессуара|لا توجد حقيبة أو إكسسوار|Aucun sac ni accessoire|बैग या ऐक्सेसरी नहीं है|没有包袋或配饰|バッグやアクセサリーがありません
Elbiseyi tek parça olarak kullan.|Wear the dress as a one-piece outfit.|Trage das Kleid als Einteiler.|Носите платье как цельный образ.|ارتدِ الفستان كقطعة واحدة.|Portez la robe seule comme pièce principale.|ड्रेस को एक ही परिधान के रूप में पहनें।|将连衣裙作为单件穿搭。|ワンピースを一枚で着こなします。
GitHub oturumu henüz doğrulanmadı.|GitHub session is not yet verified.|GitHub-Sitzung noch nicht bestätigt.|Сеанс GitHub ещё не подтверждён.|لم يتم التحقق من جلسة GitHub بعد.|Session GitHub pas encore vérifiée.|GitHub सत्र की पुष्टि बाकी है।|GitHub 会话尚未验证。|GitHub セッションは未確認です。
Sağlayıcı bakiyelerim|Provider balances|Anbieterguthaben|Балансы провайдеров|أرصدة مزودي الخدمة|Soldes des fournisseurs|प्रदाता शेषराशि|服务商余额|プロバイダー残高
AYARLAR · YAPAY ZEKÂ|SETTINGS · AI|EINSTELLUNGEN · KI|НАСТРОЙКИ · ИИ|الإعدادات · الذكاء الاصطناعي|PARAMÈTRES · IA|सेटिंग्स · एआई|设置 · AI|設定 · AI
AI HİZMETİ|AI SERVICE|KI-DIENST|СЕРВИС ИИ|خدمة الذكاء الاصطناعي|SERVICE IA|एआई सेवा|AI 服务|AI サービス
Kalan kredi (USD)|Remaining credit (USD)|Restguthaben (USD)|Остаток кредита (USD)|الرصيد المتبقي (USD)|Crédit restant (USD)|बचा हुआ क्रेडिट (USD)|剩余点数 (USD)|残高 (USD)
Menüyü aç|Open menu|Menü öffnen|Открыть меню|افتح القائمة|Ouvrir le menu|मेनू खोलें|打开菜单|メニューを開く
Menüyü kapat|Close menu|Menü schließen|Закрыть меню|أغلق القائمة|Fermer le menu|मेनू बंद करें|关闭菜单|メニューを閉じる
Ana menü|Main menu|Hauptmenü|Главное меню|القائمة الرئيسية|Menu principal|मुख्य मेनू|主菜单|メインメニュー
✦ Parçaları ayır|✦ Extract items|✦ Teile freistellen|✦ Выделить вещи|✦ افصل القطع|✦ Isoler les articles|✦ कपड़े अलग करें|✦ 提取服装|✦ 服を切り出す
Seçilenleri kaydet ✓|Save selected ✓|Auswahl speichern ✓|Сохранить выбранное ✓|احفظ المحدد ✓|Enregistrer la sélection ✓|चुने हुए सहेजें ✓|保存所选 ✓|選択した服を保存 ✓
`;
 const dictionary=new Map(phrases.trim().split('\n').map(line=>{const row=line.split('|');return [row[0],row]}));
 const field=document.getElementById('app-language');
 if(!field)return;
 const originals=new WeakMap(),attributeOriginals=new WeakMap();
 let language='tr';
 try{language=localStorage.getItem('sm-language')||'tr'}catch{}
 if(!languages.includes(language))language='tr';
 const translate=value=>{
  const trimmed=value.trim();
  const row=dictionary.get(trimmed);
  if(!row||language==='tr')return value;
  return value.replace(trimmed,row[languages.indexOf(language)]||trimmed);
 };
 const observer=new MutationObserver(records=>{
  observer.disconnect();
  for(const record of records){
   if(record.type==='characterData')localizeText(record.target);
   else if(record.type==='attributes')localizeElement(record.target);
   else for(const node of record.addedNodes)localize(node);
  }
  observe();
 });
 function localizeText(node){
  if(!node.parentElement||node.parentElement.closest('script,style,textarea,[data-token-price]'))return;
  const old=originals.get(node);
  const original=old&&node.data===old.rendered?old.original:node.data;
  const rendered=translate(original);
  originals.set(node,{original,rendered});
  if(node.data!==rendered)node.data=rendered;
 }
 function localizeElement(el){
  if(el.tagName==='OPTION'&&!el.hasAttribute('value'))el.value=el.textContent.trim();
  const values=attributeOriginals.get(el)||{};
  for(const name of ['aria-label','placeholder','title','alt']){
   const current=el.getAttribute(name);
   if(current===null)continue;
   const old=values[name],original=old&&current===old.rendered?old.original:current,rendered=translate(original);
   values[name]={original,rendered};
   if(current!==rendered)el.setAttribute(name,rendered);
  }
  attributeOriginals.set(el,values);
 }
 function localize(root){
  if(root.nodeType===Node.TEXT_NODE){localizeText(root);return}
  if(root.nodeType!==Node.ELEMENT_NODE)return;
  localizeElement(root);
  const walker=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT|NodeFilter.SHOW_TEXT);
  while(walker.nextNode()){
   const node=walker.currentNode;
   if(node.nodeType===Node.TEXT_NODE)localizeText(node);
   else localizeElement(node);
  }
 }
 function observe(){
  observer.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['aria-label','placeholder','title','alt']});
 }
 function apply(){
  observer.disconnect();
  document.documentElement.lang=language==='zh'?'zh-Hans':language;
  document.documentElement.dir=language==='ar'?'rtl':'ltr';
  field.value=language;
  const dollars=new Intl.NumberFormat(language,{style:'currency',currency:'USD',currencyDisplay:'code'});
  document.querySelectorAll('[data-token-price]').forEach(el=>{el.textContent=dollars.format(Number(el.dataset.tokenPrice)/100)});
  localize(document.body);
  observe();
 }
 field.addEventListener('change',()=>{
  if(!languages.includes(field.value))return;
  language=field.value;
  try{localStorage.setItem('sm-language',language)}catch{}
  apply();
 });
 apply();
})();
