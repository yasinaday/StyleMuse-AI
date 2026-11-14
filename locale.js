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
Bu profili kaydettiğinde hazır manken görünümün ten rengine, vücut tipine ve ölçülerine göre güncellenir.|When you save this profile, your default mannequin updates to match your skin tone, body shape and measurements.|Wenn du dieses Profil speicherst, wird die Standardfigur an deinen Hautton, deine Körperform und deine Maße angepasst.|Когда вы сохраните профиль, внешний вид манекена обновится с учётом тона кожи, типа фигуры и мерок.|عند حفظ هذا الملف، يتغير مظهر عارضة الأزياء الافتراضية وفقًا للون بشرتك وشكل جسمك وقياساتك.|En enregistrant ce profil, le mannequin par défaut s’adapte à votre teint, à votre morphologie et à vos mensurations.|इस प्रोफ़ाइल को सहेजने पर डिफ़ॉल्ट मॉडल का रूप आपकी त्वचा की रंगत, शरीर के आकार और माप के अनुसार बदलता है।|保存此档案后，默认模特会根据你的肤色、体型和身体尺寸更新。|このプロフィールを保存すると、肌の色、体型、身体のサイズに合わせて標準モデルの外見が更新されます。
Kırp ve devam et|Crop and continue|Zuschneiden und weiter|Обрезать и продолжить|قص ومتابعة|Recadrer et continuer|काटें और जारी रखें|裁剪并继续|切り抜いて続ける
Analizde yalnızca seçtiğin alan kullanılır.|Only the selected area is analyzed.|Nur der ausgewählte Bereich wird analysiert.|Анализируется только выбранная область.|يُحلَّل الجزء المحدد فقط.|Seule la zone sélectionnée est analysée.|केवल चुने हुए क्षेत्र का विश्लेषण होगा।|仅分析所选区域。|選択した範囲だけを分析します。
Fotoğrafı kaydırıp yakınlaştırarak analiz edilecek kıyafetleri çerçeveye al.|Move and zoom the photo to frame the clothes for analysis.|Verschiebe und vergrößere das Foto, um die Kleidung einzurahmen.|Переместите и увеличьте фото, чтобы выбрать одежду для анализа.|حرّك الصورة وكبّرها لتحديد الملابس المراد تحليلها.|Déplace et agrandis la photo pour cadrer les vêtements à analyser.|विश्लेषण के लिए कपड़ों को फ़्रेम में लाने हेतु फ़ोटो खिसकाएँ और ज़ूम करें।|移动并缩放照片，将要分析的衣物放入取景框。|写真を移動・拡大して、分析する服を枠に収めます。
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
Kombin kaydedildi.|Outfit saved.|Outfit gespeichert.|Образ сохранён.|تم حفظ الإطلالة.|Tenue enregistrée.|पहनावा सहेजा गया।|搭配已保存。|コーデを保存しました。
Kombin kaydedilemedi.|Could not save the outfit.|Outfit konnte nicht gespeichert werden.|Не удалось сохранить образ.|تعذّر حفظ الإطلالة.|Impossible d’enregistrer la tenue.|पहनावा सहेजा नहीं जा सका।|无法保存搭配。|コーデを保存できませんでした。
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
Açık|Light|Hell|Светлый|فاتح|Clair|हल्का|浅色|明るい
Orta|Medium|Mittel|Средний|متوسط|Moyen|मध्यम|中色|標準
Koyu|Deep|Dunkel|Тёмный|داكن|Foncé|गहरा|深色|濃い
Armut|Pear|Birne|Груша|كمثري|Poire|नाशपाती|梨形|洋ナシ型
Dikdörtgen|Rectangle|Rechteck|Прямоугольник|مستطيل|Rectangle|आयताकार|矩形|長方形
Kum saati|Hourglass|Sanduhr|Песочные часы|ساعة رملية|Sablier|घंटाघर|沙漏形|砂時計型
Oval|Oval|Oval|Овал|بيضاوي|Ovale|अंडाकार|椭圆形|楕円形
Ters üçgen|Inverted triangle|Umgekehrtes Dreieck|Перевёрнутый треугольник|مثلث مقلوب|Triangle inversé|उल्टा त्रिकोण|倒三角形|逆三角形
Seçiniz|Select|Auswählen|Выберите|اختر|Sélectionner|चुनें|请选择|選択してください
Daha fazla kategori|More categories|Weitere Kategorien|Другие категории|المزيد من الفئات|Plus de catégories|और श्रेणियाँ|更多分类|その他のカテゴリ
Kişisel|Personal|Persönlich|Личные данные|شخصي|Personnel|व्यक्तिगत|个人|個人設定
Veriler|Data|Daten|Данные|البيانات|Données|डेटा|数据|データ
Yönetim|Administration|Verwaltung|Управление|الإدارة|Administration|प्रशासन|管理|管理
Veri yedekleme|Data backup|Datensicherung|Резервное копирование|نسخ البيانات احتياطيًا|Sauvegarde des données|डेटा बैकअप|数据备份|データのバックアップ
Oturum aç|Sign in|Anmelden|Войти|تسجيل الدخول|Se connecter|साइन इन करें|登录|ログイン
Çıkış yap|Sign out|Abmelden|Выйти|تسجيل الخروج|Se déconnecter|साइन आउट करें|退出登录|ログアウト
Görünüm|Appearance|Darstellung|Внешний вид|المظهر|Apparence|दिखावट|外观|外観
Onayla|Confirm|Bestätigen|Подтвердить|تأكيد|Confirmer|पुष्टि करें|确认|確認
Stil Jetonu kullanımı|Use Style Tokens|Style-Token verwenden|Использование токенов стиля|استخدام رموز الأناقة|Utiliser des jetons Style|स्टाइल टोकन का उपयोग|使用风格点数|スタイルトークンの使用
Manken fotoğrafı|Mannequin photo|Modellfoto|Фото модели|صورة العارضة|Photo du mannequin|मॉडल की फ़ोटो|模特照片|モデルの写真
Fotoğrafı büyüt|Enlarge photo|Foto vergrößern|Увеличить фото|تكبير الصورة|Agrandir la photo|फ़ोटो बड़ी करें|放大照片|写真を拡大
Büyütmek için dokun|Tap to enlarge|Zum Vergrößern tippen|Нажмите для увеличения|اضغط للتكبير|Toucher pour agrandir|बड़ा करने के लिए टैप करें|轻触放大|タップして拡大
Büyütülmüş kıyafet fotoğrafı|Enlarged clothing photo|Vergrößertes Kleidungsfoto|Увеличенное фото одежды|صورة مكبرة للملابس|Photo agrandie du vêtement|कपड़े की बड़ी फ़ोटो|放大的服装照片|拡大した衣服の写真
Profil fotoğrafını değiştir|Change profile photo|Profilfoto ändern|Изменить фото профиля|تغيير صورة الملف الشخصي|Modifier la photo de profil|प्रोफ़ाइल फ़ोटो बदलें|更改头像|プロフィール写真を変更
Seçilen kıyafetler|Selected clothes|Ausgewählte Kleidung|Выбранная одежда|الملابس المحددة|Vêtements sélectionnés|चुने हुए कपड़े|已选衣物|選択した服
Kıyafet|Clothing|Kleidung|Одежда|ملابس|Vêtement|कपड़ा|衣物|衣服
Şapka|Hat|Hut|Головной убор|قبعة|Chapeau|टोपी|帽子|帽子
Kıyafet fotoğrafını kırp|Crop clothing photo|Kleidungsfoto zuschneiden|Обрезать фото одежды|قص صورة الملابس|Recadrer la photo du vêtement|कपड़े की फ़ोटो काटें|裁剪服装照片|服の写真を切り抜く
Kıyafeti ortaya getir. Parmağınla kaydır, alttan büyüt.|Center the garment. Drag the photo and use the slider to zoom.|Kleidung zentrieren. Foto verschieben und mit dem Regler vergrößern.|Расположите одежду по центру. Перемещайте фото и меняйте масштаб ползунком.|وسّط قطعة الملابس. حرّك الصورة واستخدم شريط التكبير.|Centre le vêtement. Déplace la photo et zoome avec le curseur.|कपड़े को बीच में रखें। फ़ोटो खिसकाएँ और स्लाइडर से ज़ूम करें।|将衣物置于中央，拖动照片并用滑块缩放。|服を中央に置き、写真をドラッグしてスライダーで拡大します。
Yalnızca seçtiğin alan kaydedilir. Arka plan otomatik silinmez.|Only the selected area is saved. The background stays in the photo.|Nur der ausgewählte Bereich wird gespeichert. Der Hintergrund bleibt erhalten.|Сохранится только выбранная область. Фон останется на фото.|تُحفظ المنطقة المحددة فقط، وتبقى الخلفية في الصورة.|Seule la zone sélectionnée est enregistrée. Le fond reste sur la photo.|केवल चुना क्षेत्र सहेजा जाएगा। पृष्ठभूमि फ़ोटो में रहेगी।|仅保存所选区域，照片背景会保留。|選択範囲だけが保存され、背景は写真に残ります。
Yapay zekâ fotoğraftaki kıyafetleri bulur ve ayrı ayrı önerir. Kaydetmeden önce kontrol edebilirsin.|AI finds garments in the photo and suggests them individually. Review them before saving.|KI erkennt die Kleidung im Foto und schlägt sie einzeln vor. Prüfe sie vor dem Speichern.|ИИ находит одежду на фото и предлагает её по отдельности. Проверьте вещи перед сохранением.|يعثر الذكاء الاصطناعي على الملابس في الصورة ويقترحها كلًا على حدة. يمكنك مراجعتها قبل الحفظ.|L’IA repère les vêtements sur la photo et les propose séparément. Vérifie-les avant de les enregistrer.|एआई फ़ोटो में कपड़े पहचानकर अलग-अलग सुझाता है। सहेजने से पहले उन्हें देख लें।|AI 会识别照片中的衣物并分别推荐，保存前可逐件检查。|AIが写真の服を見つけて個別に提案します。保存前に確認できます。
Fotoğrafı seçince kıyafete odaklanacak şekilde kırpabilirsin. Yalnızca bu cihazda saklanır.|After choosing a photo, crop it around the garment. It is stored only on this device.|Schneide das gewählte Foto um das Kleidungsstück zu. Es bleibt auf diesem Gerät.|Выбрав фото, обрежьте его по одежде. Фото хранится только на этом устройстве.|بعد اختيار الصورة، قصّها حول قطعة الملابس. تُحفظ على هذا الجهاز فقط.|Après avoir choisi une photo, recadre-la autour du vêtement. Elle est stockée uniquement sur cet appareil.|फ़ोटो चुनकर उसे कपड़े के आसपास काटें। वह केवल इस डिवाइस पर रहेगी।|选好照片后可围绕衣物裁剪。照片仅存储在此设备上。|写真を選んだら服に合わせて切り抜けます。写真はこの端末にのみ保存されます。
Sunucu kontrol ediliyor…|Checking the server…|Server wird geprüft…|Проверяем сервер…|جارٍ التحقق من الخادم…|Vérification du serveur…|सर्वर जाँचा जा रहा है…|正在检查服务器…|サーバーを確認中…
Hazırlanıyor…|Preparing…|Wird vorbereitet…|Подготовка…|جارٍ التحضير…|Préparation…|तैयारी हो रही है…|正在准备…|準備中…
Gönderiliyor…|Sending…|Wird gesendet…|Отправка…|جارٍ الإرسال…|Envoi…|भेजा जा रहा है…|正在发送…|送信中…
Sonuç bekleniyor…|Waiting for the result…|Warte auf das Ergebnis…|Ожидаем результат…|بانتظار النتيجة…|En attente du résultat…|नतीजे की प्रतीक्षा…|正在等待结果…|結果を待機中…
Sağlayıcıdan sonuç bekleniyor.|Waiting for the provider’s result.|Warte auf das Ergebnis des Anbieters.|Ожидаем результат от сервиса.|بانتظار نتيجة مزود الخدمة.|En attente du résultat du fournisseur.|सेवा के नतीजे की प्रतीक्षा है।|正在等待服务商返回结果。|サービスからの結果を待っています。
Sonuç hazır · Görseli kontrol et|Result ready · Review the image|Ergebnis fertig · Bild prüfen|Результат готов · Проверьте изображение|النتيجة جاهزة · راجع الصورة|Résultat prêt · Vérifie l’image|नतीजा तैयार · तस्वीर देखें|结果已就绪 · 检查图片|結果ができました · 画像を確認
Giydirme sonucu kurtarıldı.|Try-on result recovered.|Anprobe-Ergebnis wiederhergestellt.|Результат примерки восстановлен.|تم استرجاع نتيجة التجربة.|Résultat d’essayage récupéré.|ट्राई-ऑन का नतीजा मिल गया।|已恢复试穿结果。|試着結果を復元しました。
Yarım kalan giydirme var.|A try-on is still pending.|Eine Anprobe steht noch aus.|Примерка ещё не завершена.|هناك تجربة لم تكتمل بعد.|Un essayage est en attente.|एक ट्राई-ऑन बाकी है।|有一项试穿尚未完成。|未完了の試着があります。
Kalan parçaları giydir|Try on remaining items|Restliche Teile anprobieren|Примерить оставшиеся вещи|جرّب القطع المتبقية|Essayer les pièces restantes|बाकी कपड़े पहनाकर देखें|试穿剩余单品|残りの服を試着
Aynı giydirme işini kontrol et|Check the pending try-on|Offene Anprobe prüfen|Проверить текущую примерку|تحقق من التجربة المعلقة|Vérifier l’essayage en attente|बाकी ट्राई-ऑन जाँचें|查看待完成的试穿|保留中の試着を確認
Önceki parça|Previous item|Vorheriges Teil|Предыдущая вещь|القطعة السابقة|Pièce précédente|पिछला कपड़ा|上一件|前のアイテム
Bekleyen parça|Pending item|Ausstehendes Teil|Вещь в ожидании|القطعة المعلقة|Pièce en attente|बाकी कपड़ा|待处理单品|処理待ちのアイテム
✦ Fotoğraf analiz ediliyor…|✦ Analyzing photo…|✦ Foto wird analysiert…|✦ Анализируем фото…|✦ جارٍ تحليل الصورة…|✦ Analyse de la photo…|✦ फ़ोटो का विश्लेषण हो रहा है…|✦ 正在分析照片…|✦ 写真を分析中…
Fotoğraf hazırlanıyor…|Preparing photo…|Foto wird vorbereitet…|Подготовка фото…|جارٍ تجهيز الصورة…|Préparation de la photo…|फ़ोटो तैयार हो रही है…|正在准备照片…|写真を準備中…
Üretiliyor…|Generating…|Wird erstellt…|Создание…|جارٍ الإنشاء…|Création…|बनाया जा रहा है…|正在生成…|生成中…
Üretildi|Generated|Erstellt|Создано|تم الإنشاء|Créé|बन गया|已生成|生成済み
Henüz kayıt yok.|No entries yet.|Noch keine Einträge.|Записей пока нет.|لا توجد سجلات بعد.|Aucune entrée pour l’instant.|अभी कोई रिकॉर्ड नहीं है।|暂无记录。|記録はまだありません。
Alım ve kullanım geçmişi|Purchase and usage history|Kauf- und Nutzungsverlauf|История покупок и использования|سجل الشراء والاستخدام|Historique des achats et de l’utilisation|खरीद और उपयोग का इतिहास|购买及使用记录|購入と利用の履歴
Henüz jeton hareketi yok.|No token activity yet.|Noch keine Token-Aktivität.|Операций с токенами пока нет.|لا توجد حركات للرموز بعد.|Aucun mouvement de jetons pour l’instant.|अभी कोई टोकन गतिविधि नहीं है।|暂无点数变动。|トークンの利用履歴はまだありません。
Google Play satın alma henüz açık değil.|Google Play purchases are not available yet.|Google-Play-Käufe sind noch nicht verfügbar.|Покупки в Google Play пока недоступны.|عمليات الشراء عبر Google Play غير متاحة بعد.|Les achats Google Play ne sont pas encore disponibles.|Google Play पर खरीदारी अभी उपलब्ध नहीं है।|Google Play 购买尚未开放。|Google Playでの購入はまだ利用できません。
{n} parça|{n} items|{n} Teile|Вещей: {n}|القطع: {n}|{n} pièces|{n} कपड़े|{n} 件|{n} 点
{n} parça seçildi.|{n} items selected.|{n} Teile ausgewählt.|Выбрано вещей: {n}.|القطع المحددة: {n}.|{n} pièces sélectionnées.|{n} कपड़े चुने गए।|已选择 {n} 件。|{n} 点を選択しました。
{n} ürün seçili|{n} products selected|{n} Produkte ausgewählt|Выбрано товаров: {n}|المنتجات المحددة: {n}|{n} articles sélectionnés|{n} उत्पाद चुने गए|已选择 {n} 件商品|{n} 点の商品を選択
✦ {n} ürün tespit edildi.|✦ {n} items detected.|✦ {n} Teile erkannt.|✦ Обнаружено вещей: {n}.|✦ القطع المكتشفة: {n}.|✦ {n} articles détectés.|✦ {n} कपड़े मिले।|✦ 已识别 {n} 件衣物。|✦ {n} 点を検出しました。
Jeton bakiyesi doğrulanamadı.|Could not verify token balance.|Token-Guthaben konnte nicht geprüft werden.|Не удалось проверить баланс токенов.|تعذّر التحقق من رصيد الرموز.|Impossible de vérifier le solde de jetons.|टोकन शेष की पुष्टि नहीं हो सकी।|无法验证点数余额。|トークン残高を確認できませんでした。
Fotoğraf açılamadı|Could not open the photo|Foto konnte nicht geöffnet werden|Не удалось открыть фото|تعذّر فتح الصورة|Impossible d’ouvrir la photo|फ़ोटो नहीं खुल सकी|无法打开照片|写真を開けませんでした
Önce üst ve alt giyim veya elbise seç.|Choose a top and bottoms or a dress first.|Wähle zuerst ein Ober- und Unterteil oder ein Kleid.|Сначала выберите верх и низ или платье.|اختاري قطعة علوية وسفلية أو فستانًا أولًا.|Choisis d’abord un haut et un bas ou une robe.|पहले ऊपर और नीचे के कपड़े या एक ड्रेस चुनें।|请先选择上装和下装，或选择连衣裙。|先に上下の服かワンピースを選んでください。
6 haneli doğrulama kodu|6-digit verification code|6-stelliger Bestätigungscode|6-значный код|رمز تحقق من 6 أرقام|Code de vérification à 6 chiffres|6 अंकों का सत्यापन कोड|6 位验证码|6 桁の確認コード
E-posta kodu gönder|Email a code|Code per E-Mail senden|Отправить код по почте|أرسل الرمز بالبريد|Envoyer le code par e-mail|कोड ईमेल करें|通过邮件发送验证码|メールでコードを送信
Jeton Yükle|Add tokens|Token aufladen|Пополнить токены|شحن الرموز|Recharger les jetons|टोकन जोड़ें|充值点数|トークンを追加
Jetonları yükle|Load tokens|Token aufladen|Пополнить баланс|أضف الرموز|Ajouter les jetons|टोकन लोड करें|充值点数|トークンをチャージ
Jetonlar yüklendi.|Tokens added.|Token aufgeladen.|Токены добавлены.|تمت إضافة الرموز.|Jetons ajoutés.|टोकन जुड़ गए।|点数已充值。|トークンを追加しました。
Doğrulama kodu gönderilemedi.|Could not send the verification code.|Bestätigungscode konnte nicht gesendet werden.|Не удалось отправить код.|تعذّر إرسال رمز التحقق.|Impossible d’envoyer le code.|सत्यापन कोड भेजा नहीं जा सका।|无法发送验证码。|確認コードを送信できませんでした。
Kod geçersiz veya süresi dolmuş.|The code is invalid or expired.|Der Code ist ungültig oder abgelaufen.|Код неверен или истёк.|الرمز غير صالح أو منتهي الصلاحية.|Le code est invalide ou expiré.|कोड अमान्य है या उसकी अवधि समाप्त हो गई है।|验证码无效或已过期。|コードが無効か期限切れです。
Yeni kod istemeden önce bekle.|Wait before requesting another code.|Warte, bevor du einen neuen Code anforderst.|Подождите перед запросом нового кода.|انتظر قبل طلب رمز جديد.|Attends avant de demander un autre code.|नया कोड माँगने से पहले प्रतीक्षा करें।|请稍后再请求新验证码。|新しいコードをリクエストする前にお待ちください。
Sunucuda e-posta gönderimi henüz ayarlanmadı.|Email delivery is not configured on the server.|Der E-Mail-Versand ist auf dem Server noch nicht eingerichtet.|Отправка почты на сервере ещё не настроена.|لم يُضبط إرسال البريد على الخادم بعد.|L’envoi d’e-mails n’est pas encore configuré sur le serveur.|सर्वर पर ईमेल भेजने की व्यवस्था अभी नहीं हुई है।|服务器尚未配置邮件发送。|サーバーのメール送信がまだ設定されていません。
Canlı bakiye doğrulanamadı|Live balance could not be verified|Aktueller Kontostand konnte nicht geprüft werden|Не удалось проверить текущий баланс|تعذّر التحقق من الرصيد الحالي|Solde en temps réel non vérifié|लाइव शेष की पुष्टि नहीं हुई|无法核实实时余额|現在の残高を確認できませんでした
Son kontrol ettiğin kredi|Last balance you checked|Zuletzt geprüftes Guthaben|Последний проверенный баланс|آخر رصيد تحققت منه|Dernier solde consulté|पिछला जाँचा गया शेष|上次查询的余额|最後に確認した残高
Bakiye kaydı okunamadı.|Could not read the saved balance.|Gespeichertes Guthaben konnte nicht gelesen werden.|Не удалось прочитать сохранённый баланс.|تعذّرت قراءة الرصيد المحفوظ.|Impossible de lire le solde enregistré.|सहेजा गया शेष पढ़ा नहीं जा सका।|无法读取已保存的余额。|保存済みの残高を読み込めませんでした。
Yedekten geri yükle ↑|Restore from backup ↑|Aus Sicherung wiederherstellen ↑|Восстановить из копии ↑|استعد من النسخة الاحتياطية ↑|Restaurer depuis la sauvegarde ↑|बैकअप से पुनर्स्थापित करें ↑|从备份恢复 ↑|バックアップから復元 ↑
Yedek geri yüklendi.|Backup restored.|Sicherung wiederhergestellt.|Резервная копия восстановлена.|تمت استعادة النسخة الاحتياطية.|Sauvegarde restaurée.|बैकअप बहाल हुआ।|备份已恢复。|バックアップを復元しました。
Yedek yazılamadı.|Could not write the backup.|Sicherung konnte nicht gespeichert werden.|Не удалось записать резервную копию.|تعذّر حفظ النسخة الاحتياطية.|Impossible d’écrire la sauvegarde.|बैकअप लिखा नहीं जा सका।|无法写入备份。|バックアップを書き込めませんでした。
Bağlantı kesildi.|Connection lost.|Verbindung unterbrochen.|Соединение прервано.|انقطع الاتصال.|Connexion interrompue.|कनेक्शन टूट गया।|连接已断开。|接続が切れました。
Sunucu zamanında yanıt vermedi.|The server did not respond in time.|Der Server hat nicht rechtzeitig geantwortet.|Сервер не ответил вовремя.|لم يستجب الخادم في الوقت المحدد.|Le serveur n’a pas répondu à temps.|सर्वर ने समय पर जवाब नहीं दिया।|服务器响应超时。|サーバーの応答がタイムアウトしました。
Yapay zekâ işlemi tamamlanamadı.|The AI operation could not be completed.|Der KI-Vorgang konnte nicht abgeschlossen werden.|Не удалось завершить операцию ИИ.|تعذّر إكمال عملية الذكاء الاصطناعي.|Impossible de terminer l’opération IA.|एआई प्रक्रिया पूरी नहीं हो सकी।|无法完成 AI 操作。|AI 処理を完了できませんでした。
Yapay zekâ şu anda kullanılamıyor.|AI is currently unavailable.|KI ist derzeit nicht verfügbar.|ИИ сейчас недоступен.|الذكاء الاصطناعي غير متاح حاليًا.|L’IA est indisponible pour le moment.|एआई अभी उपलब्ध नहीं है।|AI 暂不可用。|現在 AI を利用できません。
Oturum kapatılamadı.|Could not sign out.|Abmelden fehlgeschlagen.|Не удалось выйти.|تعذّر تسجيل الخروج.|Impossible de se déconnecter.|साइन आउट नहीं हो सका।|无法退出登录。|ログアウトできませんでした。
Profil bölümünden oturum aç.|Sign in from Profile.|Melde dich im Profil an.|Войдите через раздел профиля.|سجّل الدخول من الملف الشخصي.|Connecte-toi depuis le profil.|प्रोफ़ाइल से साइन इन करें।|请在个人资料页登录。|プロフィールからログインしてください。
Fotoğraf okunamadı.|Could not read the photo.|Das Foto konnte nicht gelesen werden.|Не удалось прочитать фото.|تعذّرت قراءة الصورة.|Impossible de lire la photo.|फ़ोटो पढ़ी नहीं जा सकी।|无法读取照片。|写真を読み込めませんでした。
Kombin seçildi.|Outfit selected.|Outfit ausgewählt.|Образ выбран.|تم اختيار الإطلالة.|Tenue sélectionnée.|पहनावा चुना गया।|已选择搭配。|コーデを選択しました。
Kombin parçalarını incele|Review outfit pieces|Outfit-Teile prüfen|Проверьте вещи образа|راجع قطع الإطلالة|Vérifier les pièces de la tenue|पहनावे के कपड़े देखें|检查搭配单品|コーデのアイテムを確認
Kombin parçalarını ayır|Separate outfit pieces|Outfit-Teile trennen|Разделить вещи образа|افصل قطع الإطلالة|Séparer les pièces de la tenue|पहनावे के कपड़े अलग करें|拆分搭配单品|コーデのアイテムを分離
Seçtiğin fotoğrafın yerel önizlemesi|Local preview of your selected photo|Lokale Vorschau des gewählten Fotos|Локальный предпросмотр выбранного фото|معاينة محلية للصورة المحددة|Aperçu local de la photo sélectionnée|चुनी फ़ोटो का स्थानीय पूर्वावलोकन|所选照片的本地预览|選択した写真のローカルプレビュー
Yüklediğin kombin fotoğrafı|Your uploaded outfit photo|Dein hochgeladenes Outfit-Foto|Загруженное фото образа|صورة الإطلالة التي رفعتها|Photo de tenue importée|अपलोड की गई पहनावे की फ़ोटो|已上传的搭配照片|アップロードしたコーデ写真
Tespit edilen parçalar|Detected items|Erkannte Teile|Распознанные вещи|القطع المكتشفة|Pièces détectées|पहचाने गए कपड़े|识别出的单品|検出されたアイテム
Ürün|Item|Artikel|Вещь|قطعة|Article|उत्पाद|单品|アイテム
Üretilen ürün|Generated item|Erstellter Artikel|Созданная вещь|القطعة المنشأة|Article généré|बनाया गया उत्पाद|生成的单品|生成されたアイテム
⤢ Büyüt|⤢ Enlarge|⤢ Vergrößern|⤢ Увеличить|⤢ تكبير|⤢ Agrandir|⤢ बड़ा करें|⤢ 放大|⤢ 拡大
Boş kombin alanı|Empty outfit slot|Leerer Outfit-Platz|Пустое место в образе|خانة إطلالة فارغة|Emplacement de tenue vide|खाली पहनावा स्थान|空搭配栏|空のコーデ枠
Boş kıyafet alanı|Empty clothing slot|Leerer Kleidungsplatz|Пустое место для одежды|خانة ملابس فارغة|Emplacement de vêtement vide|खाली कपड़ा स्थान|空衣物栏|空の衣服枠
Kategori doğrulanmadı|Category not verified|Kategorie nicht bestätigt|Категория не подтверждена|لم تُتحقق الفئة|Catégorie non vérifiée|श्रेणी की पुष्टि नहीं हुई|分类未验证|カテゴリは未確認です
Maske çok küçük|Mask too small|Maske zu klein|Маска слишком мала|القناع صغير جدًا|Masque trop petit|मास्क बहुत छोटा है|蒙版太小|マスクが小さすぎます
Maske kalitesi düşük — elle kontrol et|Low mask quality — check manually|Geringe Maskenqualität – manuell prüfen|Низкое качество маски — проверьте вручную|جودة القناع منخفضة، افحصه يدويًا|Masque de faible qualité — vérifier manuellement|मास्क की गुणवत्ता कम है, खुद जाँचें|蒙版质量较低，请手动检查|マスクの品質が低いため手動で確認してください
Geçersiz tespit sonucu|Invalid detection result|Ungültiges Erkennungsergebnis|Недействительный результат распознавания|نتيجة اكتشاف غير صالحة|Résultat de détection invalide|पहचान का परिणाम अमान्य है|识别结果无效|検出結果が無効です
Geçersiz üretim sonucu|Invalid generation result|Ungültiges Erstellungsergebnis|Недействительный результат генерации|نتيجة إنشاء غير صالحة|Résultat de génération invalide|बनाया गया परिणाम अमान्य है|生成结果无效|生成結果が無効です
Geçersiz sonuç adresi.|Invalid result URL.|Ungültige Ergebnis-URL.|Недействительный адрес результата.|عنوان النتيجة غير صالح.|Adresse du résultat invalide.|नतीजे का पता अमान्य है।|结果地址无效。|結果のURLが無効です。
Fotoğraf hazır. Kıyafetlerini seç.|Photo ready. Choose your clothes.|Foto bereit. Wähle deine Kleidung.|Фото готово. Выберите одежду.|الصورة جاهزة، اختر ملابسك.|Photo prête. Choisis tes vêtements.|फ़ोटो तैयार है। कपड़े चुनें।|照片已就绪，请选择衣物。|写真が用意できました。服を選んでください。
Fotoğraf seçmelisin|Choose a photo|Wähle ein Foto|Выберите фото|اختر صورة|Choisis une photo|फ़ोटो चुनें|请选择照片|写真を選んでください
Görsel çok büyük.|The image is too large.|Das Bild ist zu groß.|Изображение слишком большое.|الصورة كبيرة جدًا.|L’image est trop grande.|तस्वीर बहुत बड़ी है।|图片过大。|画像が大きすぎます。
İşin durumu doğrulanamadı.|Could not verify job status.|Auftragsstatus konnte nicht geprüft werden.|Не удалось проверить статус задания.|تعذّر التحقق من حالة المهمة.|Impossible de vérifier l’état de la tâche.|कार्य की स्थिति की पुष्टि नहीं हुई।|无法确认任务状态。|処理状況を確認できませんでした。
Önceki giydirme kontrol ediliyor…|Checking the previous try-on…|Vorherige Anprobe wird geprüft…|Проверяем предыдущую примерку…|جارٍ التحقق من التجربة السابقة…|Vérification de l’essayage précédent…|पिछला ट्राई-ऑन जाँचा जा रहा है…|正在检查上次试穿…|前の試着を確認中…
Önceki iş doğrulanamadı.|Could not verify the previous job.|Vorheriger Auftrag konnte nicht geprüft werden.|Не удалось проверить предыдущее задание.|تعذّر التحقق من المهمة السابقة.|Impossible de vérifier la tâche précédente.|पिछले कार्य की पुष्टि नहीं हुई।|无法确认上一个任务。|前の処理を確認できませんでした。
Sağlayıcı giydirme işini tamamlayamadı.|The provider could not finish the try-on.|Der Anbieter konnte die Anprobe nicht abschließen.|Сервис не завершил примерку.|تعذّر على المزوّد إكمال التجربة.|Le fournisseur n’a pas terminé l’essayage.|सेवा ट्राई-ऑन पूरा नहीं कर सकी।|服务商未能完成试穿。|サービスが試着を完了できませんでした。
Sağlayıcı iki dakika içinde sonuç döndürmedi.|The provider did not return a result within two minutes.|Der Anbieter lieferte innerhalb von zwei Minuten kein Ergebnis.|Сервис не вернул результат за две минуты.|لم يُرجع المزوّد نتيجة خلال دقيقتين.|Le fournisseur n’a pas répondu dans les deux minutes.|सेवा ने दो मिनट में नतीजा नहीं दिया।|服务商未在两分钟内返回结果。|サービスが2分以内に結果を返しませんでした。
Stil Jetonu kalmadı.|No Style Tokens left.|Keine Style-Token mehr verfügbar.|Токены стиля закончились.|نفدت رموز الأناقة.|Il ne reste plus de jetons Style.|स्टाइल टोकन खत्म हो गए।|风格点数已用完。|スタイルトークンがありません。
Kombin kaydı başarısız|Outfit save failed|Outfit konnte nicht gespeichert werden|Не удалось сохранить образ|تعذّر حفظ الإطلالة|Échec de l’enregistrement de la tenue|पहनावा सहेजा नहीं गया|保存搭配失败|コーデの保存に失敗しました
Kombin kaydı iptal edildi|Outfit save canceled|Speichern des Outfits abgebrochen|Сохранение образа отменено|أُلغي حفظ الإطلالة|Enregistrement de la tenue annulé|पहनावा सहेजना रद्द हुआ|已取消保存搭配|コーデの保存を中止しました
Parçayı kaydet ve devam et|Save item and continue|Teil speichern und fortfahren|Сохранить вещь и продолжить|احفظ القطعة وتابع|Enregistrer l’article et continuer|कपड़ा सहेजें और जारी रखें|保存单品并继续|アイテムを保存して続ける
{n} kayıtlı kombin|{n} saved outfits|{n} gespeicherte Outfits|Сохранённых образов: {n}|الإطلالات المحفوظة: {n}|Tenues enregistrées : {n}|{n} सहेजे गए पहनावे|{n} 套已保存搭配|保存済みのコーデ {n} 件
{n} kıyafet|{n} garments|{n} Kleidungsstücke|Предметов одежды: {n}|قطع الملابس: {n}|Vêtements : {n}|{n} कपड़े|{n} 件衣物|衣服 {n} 点
{n} parça kaydedildi|{n} items saved|{n} Teile gespeichert|Сохранено вещей: {n}|القطع المحفوظة: {n}|Articles enregistrés : {n}|{n} कपड़े सहेजे गए|已保存 {n} 件单品|{n} 点を保存しました
{n} jeton için kod e-postana gönderildi.|A code for {n} tokens was emailed to you.|Ein Code für {n} Token wurde dir per E-Mail gesendet.|Код для {n} токенов отправлен на почту.|أُرسل رمز شحن {n} من الرموز إلى بريدك.|Un code pour {n} jetons t’a été envoyé par e-mail.|{n} टोकन का कोड ईमेल पर भेजा गया।|已通过邮件发送 {n} 个点数的验证码。|{n} トークンのコードをメールで送信しました。
Bu kayıtlı kombini kaldırmak istiyor musun?|Remove this saved outfit?|Dieses gespeicherte Outfit entfernen?|Удалить сохранённый образ?|هل تريد حذف هذه الإطلالة المحفوظة؟|Supprimer cette tenue enregistrée ?|यह सहेजा गया पहनावा हटाएँ?|删除这套已保存的搭配？|保存済みのコーデを削除しますか？
Bu kıyafeti dolabından silmek istiyor musun?|Remove this garment from your wardrobe?|Dieses Teil aus deiner Garderobe entfernen?|Удалить эту вещь из гардероба?|هل تريد حذف هذه القطعة من خزانتك؟|Retirer ce vêtement de ton dressing ?|यह कपड़ा अपनी अलमारी से हटाएँ?|从衣橱中删除这件衣物？|この服をワードローブから削除しますか？
Kıyafetler cihazındaki tarayıcıda tutulur. Tarayıcı verilerini silersen kayıtlar kaybolabilir.|Clothes are stored in this browser. Clearing browser data may erase them.|Kleidung wird im Browser gespeichert. Beim Löschen der Browserdaten können die Einträge verloren gehen.|Вещи хранятся в браузере. При удалении данных браузера записи могут исчезнуть.|تُحفظ الملابس في المتصفح. قد تفقدها عند مسح بياناته.|Les vêtements sont stockés dans le navigateur. Effacer ses données peut supprimer les enregistrements.|कपड़े ब्राउज़र में सहेजे जाते हैं। ब्राउज़र डेटा मिटाने से रिकॉर्ड खो सकते हैं।|衣物保存在浏览器中。清除浏览器数据可能会删除记录。|服はブラウザーに保存されます。ブラウザーデータを消去すると記録が失われることがあります。
Fotoğrafın analiz için gönderilecek. Bu işlem 1 Stil Jetonu kullanır. Devam edilsin mi?|Your photo will be sent for analysis. This uses 1 Style Token. Continue?|Dein Foto wird zur Analyse gesendet. Dies kostet 1 Style-Token. Fortfahren?|Фото будет отправлено на анализ. Будет списан 1 токен стиля. Продолжить?|ستُرسل صورتك للتحليل مقابل رمز أناقة واحد. هل تريد المتابعة؟|Ta photo sera envoyée pour analyse. Cela coûte 1 jeton Style. Continuer ?|विश्लेषण के लिए फ़ोटो भेजी जाएगी। इसमें 1 स्टाइल टोकन लगेगा। जारी रखें?|照片将发送进行分析，需消耗 1 个风格点数。继续吗？|写真を分析のため送信します。1 スタイルトークンを使用します。続けますか？
Analiz iptal edildi; ücretli istek yapılmadı.|Analysis canceled before submitting a paid request.|Analyse vor dem kostenpflichtigen Auftrag abgebrochen.|Анализ отменён до отправки платного запроса.|أُلغي التحليل قبل إرسال طلب مدفوع.|Analyse annulée avant l’envoi de la demande payante.|भुगतान वाला अनुरोध भेजने से पहले विश्लेषण रद्द हुआ।|已在提交付费请求前取消分析。|有料リクエストの送信前に分析を中止しました。
Kalan parçalarla devam edebilirsin.|You can continue with the remaining items.|Du kannst mit den übrigen Teilen fortfahren.|Можно продолжить с оставшимися вещами.|يمكنك المتابعة مع القطع المتبقية.|Tu peux continuer avec les pièces restantes.|बाकी कपड़ों के साथ जारी रख सकते हैं।|可以继续试穿剩余单品。|残りのアイテムで続けられます。
Aynı giydirme işini kontrol et düğmesini kullan.|Use the button to check the pending try-on.|Nutze die Schaltfläche, um die offene Anprobe zu prüfen.|Проверьте ожидающую примерку с помощью кнопки.|استخدم زر التحقق من التجربة المعلقة.|Utilise le bouton pour vérifier l’essayage en attente.|बाकी ट्राई-ऑन जाँचने वाला बटन दबाएँ।|使用按钮查看待完成的试穿。|ボタンから保留中の試着を確認してください。
Otomatik ücretli tekrar yapılmadı.|No paid retry was made automatically.|Es wurde kein kostenpflichtiger Versuch automatisch wiederholt.|Автоматической платной попытки не было.|لم تُجرَ إعادة محاولة مدفوعة تلقائيًا.|Aucun nouvel essai payant n’a été lancé automatiquement.|भुगतान वाला प्रयास अपने आप नहीं दोहराया गया।|未自动进行付费重试。|有料の再試行は自動では行われませんでした。
Elle kırpma seçeneği kullanılabilir.|You can crop the photo manually.|Du kannst das Foto manuell zuschneiden.|Можно обрезать фото вручную.|يمكنك قص الصورة يدويًا.|Tu peux recadrer la photo manuellement.|फ़ोटो को हाथ से काट सकते हैं।|可以手动裁剪照片。|写真を手動で切り抜けます。
{n}/{m} parça giydirildi.|{n}/{m} items tried on.|{n}/{m} Teile anprobiert.|Примерено {n}/{m} вещей.|تمت تجربة {n} من {m} قطع.|{n}/{m} pièces essayées.|{m} में से {n} कपड़े पहनाए गए।|已试穿 {n}/{m} 件单品。|{n}/{m} 点を試着しました。
{n} ürün dolabına kaydedildi.|{n} items saved to your wardrobe.|{n} Teile in deiner Garderobe gespeichert.|В гардероб сохранено вещей: {n}.|تم حفظ {n} قطع في خزانتك.|{n} articles enregistrés dans ton dressing.|{n} कपड़े अलमारी में सहेजे गए।|已将 {n} 件单品保存到衣橱。|{n} 点をワードローブに保存しました。
{n} kıyafet dolabına kaydedildi.|{n} garments saved to your wardrobe.|{n} Kleidungsstücke in deiner Garderobe gespeichert.|В гардероб сохранено вещей: {n}.|تم حفظ {n} قطع في خزانتك.|{n} vêtements enregistrés dans ton dressing.|{n} कपड़े अलमारी में सहेजे गए।|已将 {n} 件衣物保存到衣橱。|{n} 点の服をワードローブに保存しました。
Beyaz ceketli kadın model|Woman wearing a white jacket|Frau in weißer Jacke|Женщина в белом жакете|امرأة ترتدي سترة بيضاء|Femme portant une veste blanche|सफ़ेद जैकेट पहने महिला|穿白色夹克的女模特|白いジャケットを着た女性
Örn. 0.92|e.g. 0.92|z. B. 0,92|Напр. 0,92|مثال: 0.92|Ex. 0,92|जैसे 0.92|例如 0.92|例：0.92
Fotoğraf 25 MB sınırını aşıyor.|The photo exceeds 25 MB.|Das Foto überschreitet 25 MB.|Фото превышает 25 МБ.|تتجاوز الصورة 25 ميغابايت.|La photo dépasse 25 Mo.|फ़ोटो 25 एमबी से बड़ी है।|照片超过 25 MB。|写真が25 MBを超えています。
En fazla 6 MB PNG veya JPEG fotoğraf seç.|Choose a PNG or JPEG up to 6 MB.|Wähle ein PNG- oder JPEG-Foto bis 6 MB.|Выберите фото PNG или JPEG до 6 МБ.|اختر صورة PNG أو JPEG بحجم لا يتجاوز 6 ميغابايت.|Choisis une photo PNG ou JPEG de 6 Mo maximum.|6 एमबी तक की PNG या JPEG फ़ोटो चुनें।|请选择不超过 6 MB 的 PNG 或 JPEG 照片。|6 MB以下のPNGまたはJPEG写真を選んでください。
Yalnızca PNG veya JPEG fotoğraf kullanılabilir.|Only PNG and JPEG photos are supported.|Nur PNG- und JPEG-Fotos werden unterstützt.|Поддерживаются только PNG и JPEG.|تُقبل صور PNG أو JPEG فقط.|Seules les photos PNG ou JPEG sont acceptées.|केवल PNG या JPEG फ़ोटो इस्तेमाल कर सकते हैं।|仅支持 PNG 和 JPEG 照片。|PNGまたはJPEGの写真を使用してください。
Seçilen manken fotoğrafı|Selected mannequin photo|Ausgewähltes Modellfoto|Выбранное фото модели|صورة العارضة المحددة|Photo du mannequin sélectionnée|चुनी हुई मॉडल फ़ोटो|所选模特照片|選択したモデルの写真
Kıyafet türü {n}|Clothing type {n}|Kleidungstyp {n}|Тип одежды {n}|نوع الملابس {n}|Type de vêtement {n}|कपड़े का प्रकार {n}|衣物类型 {n}|服の種類 {n}
Kıyafet parçası {n}|Garment {n}|Kleidungsstück {n}|Вещь {n}|قطعة ملابس {n}|Vêtement {n}|कपड़ा {n}|衣物 {n}|衣服 {n}
{n} Stil Jetonu|{n} Style Tokens|{n} Style-Token|Токены стиля: {n}|رموز الأناقة: {n}|{n} jetons Style|{n} स्टाइल टोकन|{n} 个风格点数|{n} スタイルトークン
{n} parça için {m} Stil Jetonu kullanılacak. Devam edilsin mi?|Use {m} Style Tokens for {n} items. Continue?|{m} Style-Token für {n} Teile verwenden. Fortfahren?|Использовать {m} токенов для {n} вещей. Продолжить?|سيُستخدم {m} من رموز الأناقة لـ {n} قطع. هل تتابع؟|Utiliser {m} jetons Style pour {n} pièces. Continuer ?|{n} कपड़ों के लिए {m} स्टाइल टोकन लगेंगे। जारी रखें?|为 {n} 件单品使用 {m} 个风格点数。继续吗？|{n} 点に {m} スタイルトークンを使います。続けますか？
{n} ürün için {m} Stil Jetonu kullanılacak. Devam edilsin mi?|Use {m} Style Tokens for {n} products. Continue?|{m} Style-Token für {n} Artikel verwenden. Fortfahren?|Использовать {m} токенов для {n} товаров. Продолжить?|سيُستخدم {m} من رموز الأناقة لـ {n} منتجات. هل تتابع؟|Utiliser {m} jetons Style pour {n} articles. Continuer ?|{n} उत्पादों के लिए {m} स्टाइल टोकन लगेंगे। जारी रखें?|为 {n} 件商品使用 {m} 个风格点数。继续吗？|{n} 点の商品に {m} スタイルトークンを使います。続けますか？
Üretim başarısız.|Generation failed.|Erstellung fehlgeschlagen.|Не удалось создать изображение.|تعذّر إنشاء الصورة.|La génération a échoué.|तस्वीर बन नहीं सकी।|生成失败。|生成に失敗しました。
Geri yüklenemedi.|Could not restore the backup.|Wiederherstellung fehlgeschlagen.|Не удалось восстановить резервную копию.|تعذّرت استعادة النسخة الاحتياطية.|Impossible de restaurer la sauvegarde.|बैकअप बहाल नहीं हो सका।|无法恢复备份。|バックアップを復元できませんでした。
Paylaşım başlatılamadı.|Could not start sharing.|Teilen konnte nicht gestartet werden.|Не удалось начать отправку.|تعذّر بدء المشاركة.|Impossible de lancer le partage.|शेयर करना शुरू नहीं हो सका।|无法开始分享。|共有を開始できませんでした。
Elle kırp|Crop manually|Manuell zuschneiden|Обрезать вручную|قص يدويًا|Recadrer manuellement|हाथ से काटें|手动裁剪|手動で切り抜く
Ayrılabilecek kıyafet bulunamadı. Elle kırpma seçeneği kullanılabilir.|No clothing suitable for extraction was found. You can crop manually.|Keine geeignete Kleidung gefunden. Du kannst das Foto manuell zuschneiden.|Не найдено подходящей одежды. Фото можно обрезать вручную.|لم يُعثر على ملابس قابلة للفصل. يمكنك قص الصورة يدويًا.|Aucun vêtement à isoler n’a été trouvé. Tu peux recadrer la photo manuellement.|अलग करने लायक कपड़े नहीं मिले। फ़ोटो को हाथ से काट सकते हैं।|未找到可分离的衣物，可以手动裁剪。|分離できる服が見つかりませんでした。手動で切り抜けます。
✦ Parçaları iyileştir|✦ Refine items|✦ Teile verbessern|✦ Улучшить вещи|✦ حسّن القطع|✦ Améliorer les articles|✦ कपड़े सुधारें|✦ 优化单品|✦ アイテムを補正
Seçilen parçaları incele|Review selected items|Ausgewählte Teile prüfen|Проверить выбранные вещи|راجع القطع المحددة|Examiner les articles sélectionnés|चुने हुए कपड़े देखें|查看所选单品|選択したアイテムを確認
Fotoğraf analizi · Ürün seçimi|Photo analysis · Select items|Fotoanalyse · Teile auswählen|Анализ фото · Выбор вещей|تحليل الصورة · اختيار القطع|Analyse photo · Sélection des articles|फ़ोटो विश्लेषण · कपड़े चुनें|照片分析 · 选择单品|写真分析 · アイテム選択
Seçilen parçaların analizi|Review selected items|Ausgewählte Teile analysieren|Анализ выбранных вещей|تحليل القطع المحددة|Analyse des articles sélectionnés|चुने हुए कपड़ों का विश्लेषण|分析所选单品|選択したアイテムの分析
↗ Paylaş|↗ Share|↗ Teilen|↗ Поделиться|↗ مشاركة|↗ Partager|↗ साझा करें|↗ 分享|↗ 共有
✕ Sil|✕ Delete|✕ Löschen|✕ Удалить|✕ حذف|✕ Supprimer|✕ हटाएँ|✕ 删除|✕ 削除
Kurtarılan giydirme|Recovered try-on|Wiederhergestellte Anprobe|Восстановленная примерка|تجربة مستعادة|Essayage récupéré|बहाल किया गया ट्राई-ऑन|已恢复的试穿|復元した試着
Kombini büyüt|Enlarge outfit|Outfit vergrößern|Увеличить образ|تكبير الإطلالة|Agrandir la tenue|पहनावा बड़ा करें|放大搭配|コーデを拡大
Giydirme sonucu|Try-on result|Anprobe-Ergebnis|Результат примерки|نتيجة التجربة|Résultat de l’essayage|ट्राई-ऑन का नतीजा|试穿结果|試着結果
Henüz manken üzerinde tamamlanmış bir kombin kaydedilmedi.|No completed try-on outfit has been saved yet.|Noch kein fertiges Outfit gespeichert.|Готовых сохранённых образов пока нет.|لم تُحفظ أي إطلالة مكتملة بعد.|Aucune tenue essayée n’a encore été enregistrée.|अभी कोई पूरा पहनावा सहेजा नहीं गया है।|尚未保存试穿搭配。|保存済みの試着コーデはまだありません。
StyleMuse kombinim|My StyleMuse outfit|Mein StyleMuse-Outfit|Мой образ StyleMuse|إطلالتي في StyleMuse|Ma tenue StyleMuse|मेरा StyleMuse पहनावा|我的 StyleMuse 搭配|私のStyleMuseコーデ
Kombinime bak!|Check out my outfit!|Schau dir mein Outfit an!|Посмотри на мой образ!|شاهد إطلالتي!|Regarde ma tenue !|मेरा पहनावा देखें!|看看我的搭配！|私のコーデを見て！
Uygulamayı değerlendir|Rate the app|App bewerten|Оценить приложение|قيّم التطبيق|Évaluer l’application|ऐप को रेट करें|评价应用|アプリを評価
Uygulamayı paylaş|Share the app|App teilen|Поделиться приложением|شارك التطبيق|Partager l’application|ऐप साझा करें|分享应用|アプリを共有
1 ile 5 arasında yıldız seç.|Choose a rating from 1 to 5 stars.|Wähle 1 bis 5 Sterne.|Выберите от 1 до 5 звёзд.|اختر من نجمة إلى خمس نجوم.|Choisis de 1 à 5 étoiles.|1 से 5 स्टार चुनें।|请选择 1 到 5 星。|1〜5の星を選んでください。
Değerlendirmen bu cihazda kaydedildi.|Your rating was saved on this device.|Deine Bewertung wurde auf diesem Gerät gespeichert.|Оценка сохранена на этом устройстве.|حُفظ تقييمك على هذا الجهاز.|Ton évaluation a été enregistrée sur cet appareil.|रेटिंग इस डिवाइस पर सहेजी गई।|评分已保存在此设备上。|この端末に評価を保存しました。
Değerlendirme kaydedilemedi.|Could not save the rating.|Bewertung konnte nicht gespeichert werden.|Не удалось сохранить оценку.|تعذّر حفظ التقييم.|Impossible d’enregistrer l’évaluation.|रेटिंग सहेजी नहीं जा सकी।|无法保存评分。|評価を保存できませんでした。
Uygulama bağlantısı kopyalandı.|App link copied.|App-Link kopiert.|Ссылка скопирована.|تم نسخ رابط التطبيق.|Lien de l’application copié.|ऐप लिंक कॉपी हुआ।|应用链接已复制。|アプリのリンクをコピーしました。
Jeton bakiyesi kontrol ediliyor.|Checking token balance.|Token-Guthaben wird geprüft.|Проверяем баланс токенов.|جارٍ التحقق من رصيد الرموز.|Vérification du solde de jetons.|टोकन शेष जाँचा जा रहा है।|正在检查点数余额。|トークン残高を確認中です。
Oturum ve analiz servisi kontrol ediliyor.|Checking sign-in and analysis service.|Anmeldung und Analysedienst werden geprüft.|Проверяем вход и сервис анализа.|جارٍ التحقق من تسجيل الدخول وخدمة التحليل.|Vérification de la connexion et du service d’analyse.|साइन-इन और विश्लेषण सेवा की जाँच हो रही है।|正在检查登录和分析服务。|ログインと分析サービスを確認中です。
Analiz teklifi hazırlanıyor.|Preparing the analysis quote.|Analyseangebot wird erstellt.|Готовим предложение для анализа.|جارٍ إعداد تكلفة التحليل.|Préparation du devis d’analyse.|विश्लेषण का अनुमान तैयार हो रहा है।|正在准备分析报价。|分析の見積もりを準備中です。
Jeton onayı bekleniyor.|Waiting for token approval.|Warte auf Token-Freigabe.|Ожидаем подтверждения токенов.|بانتظار تأكيد استخدام الرموز.|En attente de la confirmation des jetons.|टोकन की पुष्टि की प्रतीक्षा है।|正在等待点数确认。|トークンの使用確認を待っています。
Fotoğraf gönderiliyor ve kıyafet tespiti bekleniyor.|Sending photo and waiting for detection.|Foto wird gesendet. Warte auf die Erkennung.|Отправляем фото и ожидаем распознавания.|جارٍ إرسال الصورة وانتظار اكتشاف الملابس.|Envoi de la photo et attente de la détection.|फ़ोटो भेजी जा रही है और पहचान की प्रतीक्षा है।|正在发送照片并等待识别。|写真を送信し、服の検出を待っています。
Bulunan parçalar kontrol ediliyor.|Checking detected garments.|Erkannte Kleidungsstücke werden geprüft.|Проверяем распознанные вещи.|جارٍ التحقق من الملابس المكتشفة.|Vérification des vêtements détectés.|पहचाने गए कपड़े जाँचे जा रहे हैं।|正在检查识别出的衣物。|検出した服を確認中です。
Durdu|Stopped|Angehalten|Остановлено|توقف|Arrêt|रुका|已停止|停止
Analiz için yeterli Stil Jetonu yok.|Not enough Style Tokens for analysis.|Nicht genug Style-Token für die Analyse.|Недостаточно токенов для анализа.|رموز الأناقة غير كافية للتحليل.|Jetons Style insuffisants pour l’analyse.|विश्लेषण के लिए पर्याप्त स्टाइल टोकन नहीं हैं।|风格点数不足，无法分析。|分析に必要なスタイルトークンが不足しています。
`;
 const dictionary=new Map(phrases.trim().split('\n').map(line=>{const row=line.split('|');return [row[0],row]}));
 const field=document.getElementById('app-language');
 if(!field)return;
 const originals=new WeakMap(),attributeOriginals=new WeakMap();
 let language='tr';
 try{language=localStorage.getItem('sm-language')||'tr'}catch{}
 if(!languages.includes(language))language='tr';
 const templates=[...dictionary].filter(([key])=>key.includes('{n}')).map(([key,row])=>{
  const slots=[];
  const source=key.split(/(\{[nm]\})/).map(part=>{
   if(part==='{n}'||part==='{m}'){slots.push(part);return '(\\d+)';}
   return part.replace(/[.*+?^$(){}|[\]\\]/g,'\\$&');
  }).join('');
  return {regex:new RegExp('^'+source+'$'),slots,row};
 });
 function translateSegment(value){
  const trimmed=value.trim();
  const index=languages.indexOf(language);
  const row=dictionary.get(trimmed);
  if(row)return value.replace(trimmed,row[index]||trimmed);
  for(const {regex,slots,row} of templates){
   const match=regex.exec(trimmed);
   if(!match)continue;
   const format=new Intl.NumberFormat(language);
   const numbers=new Map(slots.map((slot,i)=>[slot,format.format(Number(match[i+1]))]));
   return value.replace(trimmed,row[index].replace(/\{[nm]\}/g,slot=>numbers.get(slot)??slot));
  }
  return value;
 }
 function translateLine(value){
  const numbered=value.match(/^(\d+\. )(.+)$/);
  if(numbered)return numbered[1]+translateSegment(numbered[2]);
  const stopped=value.match(/^(Durdu)(: .+)$/);
  if(stopped)return translateSegment(stopped[1])+stopped[2];
  return translateSegment(value);
 }
 const translate=value=>{
  if(language==='tr')return value;
  const whole=translateSegment(value);
  if(whole!==value)return whole;
  return value.split(/( · |\n)/).map(translateLine).join('');
 };
 window.styleMuseTranslate=translate;
 window.styleMuseSourceText=element=>Array.from(element.childNodes,node=>node.nodeType===Node.TEXT_NODE?(originals.get(node)?.original??node.data):node.textContent).join('');
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
  for(const name of ['aria-label','placeholder','title','alt','data-zoom-label']){
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
  observer.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['aria-label','placeholder','title','alt','data-zoom-label']});
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
