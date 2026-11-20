import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'closet.dart';
import 'localization.dart';
import 'photo_crop.dart';
import 'admin_api.dart';
import 'admin_page.dart';
import 'play_billing.dart';
import 'profile_editor.dart';
import 'native_api.dart';
import 'backup_page.dart';
import 'stylemuse_api.dart';
import 'native_services.dart';
import 'large_analysis_review.dart';
import 'processing_photo.dart';
import 'mannequin_page.dart';
import 'model_images.dart';
import 'web_nav_icon.dart';
import 'saved_looks_grid.dart';

class LocalStrings extends InheritedWidget {
  const LocalStrings({super.key, required this.language, required super.child});
  final String language;
  @override
  bool updateShouldNotify(LocalStrings old) => old.language != language;
}

class SmText extends StatelessWidget {
  const SmText(this.data, {super.key, this.style, this.textAlign});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => Text(
      translate(
          data,
          context
                  .dependOnInheritedWidgetOfExactType<LocalStrings>()
                  ?.language ??
              'tr'),
      style: style,
      textAlign: textAlign);
}

void main() => runApp(const StyleMuseApp());

class StyleMuseApp extends StatelessWidget {
  const StyleMuseApp({super.key, this.store, this.pickPhoto, this.api});
  final ClosetStore? store;
  final StyleMuseApi? api;
  final Future<Uint8List?> Function(ImageSource)? pickPhoto;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'StyleMuse AI',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF753978),
                brightness: Brightness.light,
                surface: const Color(0xFFFFFAFD)),
            scaffoldBackgroundColor: const Color(0xFFFCF6FA),
            appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFFCF6FA),
                foregroundColor: Color(0xFF54265F),
                centerTitle: false,
                elevation: 0,
                scrolledUnderElevation: 0),
            inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFE4CCE2))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFE4CCE2))),
                filled: true,
                fillColor: const Color(0xFFFFFAFD)),
            filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF753978),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700))),
            cardTheme: const CardThemeData(
                margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias)),
        home: StyleMuseShell(store: store, pickPhoto: pickPhoto, api: api),
      );
}

bool googleAvatarUrl(String source) {
  final uri = Uri.tryParse(source);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      const {
        'lh3.googleusercontent.com',
        'lh4.googleusercontent.com',
        'lh5.googleusercontent.com',
        'lh6.googleusercontent.com',
      }.contains(uri.host);
}

class GalleryPhoto extends StatefulWidget {
  const GalleryPhoto(this.source, {super.key});
  final String source;

  @override
  State<GalleryPhoto> createState() => _GalleryPhotoState();
}

class _GalleryPhotoState extends State<GalleryPhoto> {
  late Widget thumbnail = buildThumbnail();

  Widget buildThumbnail() => photo(widget.source, fit: BoxFit.contain, cacheWidth: 480);

  @override
  void didUpdateWidget(GalleryPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) thumbnail = buildThumbnail();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialog) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(dialog),
        child: SafeArea(child: InteractiveViewer(
          maxScale: 5,
          child: Center(child: photo(widget.source, fit: BoxFit.contain)),
        )),
      ),
    ),
    child: thumbnail,
  );
}

Widget photo(String source,
    {BoxFit fit = BoxFit.cover, double? width, double? height, int? cacheWidth}) {
  if (source.startsWith('data:')) {
    try {
      return Image.memory(base64Decode(source.substring(source.indexOf(',') + 1)),
          cacheWidth: cacheWidth,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, error, stack) =>
              const Center(child: Icon(Icons.broken_image_outlined)));
    } catch (_) {/* Invalid imported image */}
  }
  if (source.startsWith('https:') &&
      (safeOutfitPhoto(source) || googleAvatarUrl(source))) {
    return Image.network(source,
        cacheWidth: cacheWidth,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, error, stack) =>
            const Center(child: Icon(Icons.broken_image_outlined)));
  }
  return Image.asset(source,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, error, stack) =>
          const Center(child: Icon(Icons.checkroom, size: 48)));
}

class StyleMuseShell extends StatefulWidget {
  const StyleMuseShell({super.key, this.store, this.pickPhoto, this.api});
  final ClosetStore? store;
  final StyleMuseApi? api;
  final Future<Uint8List?> Function(ImageSource)? pickPhoto;
  @override
  State<StyleMuseShell> createState() => _StyleMuseShellState();
}

class _StyleMuseShellState extends State<StyleMuseShell>
    with WidgetsBindingObserver {
  Timer? recoveryTimer;
  late final Future<void> initialLoad;
  String? pendingAction;
  String? operationError;
  bool analysisFeedback = false;
  bool reviewOpen = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => resumePending());
      WidgetsBinding.instance.scheduleFrame();
      billing?.recover();
    }
  }

  Future<void> resumePending() async {
    await initialLoad;
    if (!mounted) return;
    await refreshPending();
    if (mounted && hasPending && !busy && !reviewOpen) {
      setState(() => tab = pendingAction == 'tryon' ? 3 : 1);
      if (pendingAction == 'tryon' &&
          await api.storage.read('stylemuse.tryon.run') != null) return;
      await recoverOperation();
    }
  }

  late final ClosetStore store = widget.store ?? ClosetStore();
  late final StyleMuseApi api =
      widget.api ?? StyleMuseApi(storage: const NativeSecureStore());
  late final TokenWorkflowController workflow =
      TokenWorkflowController(api: api, storage: api.storage);
  PlayBillingController? billing;
  Future<void> prepareBilling() async {
    final owner = signedInUser?['id'];
    if (owner is! String) return;
    try {
      final config = await api.post('/api/billing/play/config', {});
      if (!mounted || signedInUser?['id'] != owner) return;
      final accountId = config['account_id'];
      final ids = config['product_ids'];
      if (accountId is! String ||
          ids is! List ||
          ids.any((id) => id is! String)) return;
      final controller = PlayBillingController(verify: (product, token) async {
        if (signedInUser?['id'] != owner) throw StateError('account_changed');
        final result = await api.post('/api/billing/play/verify',
            {'product_id': product, 'purchase_token': token});
        if (signedInUser?['id'] != owner) throw StateError('account_changed');
        if (result['status'] == 'credited') {
          final updated = await api.account();
          if (mounted && signedInUser?['id'] == owner)
            setState(() => account = updated);
        }
        return PlayVerification(
            credited: result['status'] == 'credited',
            consumed: result['consumed'] == true);
      });
      final amounts = config['tokens_by_product'];
      if (amounts is Map) controller.tokensByProduct = Map<String, int>.from(amounts);
      billing?.dispose();
      billing = controller;
      await controller.initialize(
          accountId: accountId, productIds: ids.cast<String>().toSet());
      if (mounted && identical(billing, controller)) setState(() {});
    } catch (_) {/* Missing Console/server config keeps checkout disabled. */}
  }

  Map<String, dynamic>? account;
  bool accountBusy = false;
  Map? get signedInUser {
    final user = account?['user'];
    return user is Map && user['id'] is String ? user : null;
  }

  String? get accountProfilePrefix {
    final id = signedInUser?['id'];
    return id is String ? 'google:$id:' : null;
  }

  String? get accountDisplayName {
    final prefix = accountProfilePrefix;
    if (prefix == null) return null;
    for (final value in [
      store.profile['${prefix}name'],
      signedInUser?['name'],
      signedInUser?['email']
    ]) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? get accountDisplayPhoto {
    final prefix = accountProfilePrefix;
    if (prefix == null) return null;
    final remote = NativeAvatarApi.restoredPhoto(account!,
        ownerId: signedInUser!['id'] as String);
    if (remote != null) return remote;
    final candidate = store.profile['${prefix}photo'];
    if (candidate != null && safeImage(candidate)) return candidate;
    final url = signedInUser?['picture'];
    return url is String && googleAvatarUrl(url) ? url : null;
  }

  bool hasPending = false;
  bool hasTryOnRun = false;
  Future<void> refreshPending() async {
    try {
      final saved = await api.storage.read(TokenWorkflowController.pendingKey);
      final value = saved == null ? null : jsonDecode(saved);
      final run = await api.storage.read('stylemuse.tryon.run');
      if (mounted)
        setState(() {
          hasTryOnRun = run != null;
          hasPending = value is Map &&
              ['detect', 'generate', 'tryon'].contains(value['action']);
          pendingAction = hasPending ? value['action'] as String : null;
          if (pendingAction == 'detect' && value['inputs'] is Map) {
            final source = value['inputs']['image'];
            if (source is String &&
                source.startsWith('data:') &&
                safeImage(source)) {
              try {
                croppedAnalysisPhoto = base64Decode(source.split(',').last);
              } catch (_) {
                /* Keep the durable recovery available for malformed previews. */
              }
            }
          }
        });
    } catch (_) {
      if (mounted) setState(() => hasPending = false);
    }
  }

  List<String>? plannedItems;
  bool showIdeas = false;
  int ideaOffset = 0;

  List<ClosetItem> get outfitIdea {
    List<ClosetItem> category(String c) =>
        store.items.where((i) => i.category == c).toList();
    final tops = category('Üst giyim');
    final bottoms = category('Alt giyim');
    final dresses = category('Elbise');
    final pairs = tops.length * bottoms.length;
    final count = pairs + dresses.length;
    if (count == 0) return [];

    // Category is the only style metadata in the wardrobe. Prefer dresses
    // for evening/formal/romantic looks, and separates for everyday/office.
    final dressFirst = outfitPlan == 'Akşam yemeği' ||
        outfitPlan == 'Özel davet' ||
        outfitStyle == 'Romantik';
    final index = ideaOffset % count;
    final dressIndex = dressFirst ? index : index - pairs;
    final pairIndex = dressFirst ? index - dresses.length : index;
    final base = dressIndex >= 0 && dressIndex < dresses.length
        ? [dresses[dressIndex]]
        : [tops[pairIndex % tops.length], bottoms[pairIndex ~/ tops.length]];

    final extras = [
      if (outfitPlan == 'İş / Ofis' || outfitStyle == 'Modern klasik')
        category('Dış giyim'),
      if (outfitStyle != 'Minimal' && outfitPlan != 'Günlük') category('Çanta'),
      if (outfitStyle == 'Romantik' && outfitPlan != 'Günlük')
        category('Aksesuar'),
    ];
    return [
      ...base,
      for (final group in extras)
        if (group.isNotEmpty) group[index % group.length]
    ];
  }

  int tab = 0;
  String filter = 'Tümü';
  String addCategory = 'Üst giyim';
  String outfitPlan = 'Günlük', outfitStyle = 'Rahat ve şık';
  String? error;
  static const labels = [
    'Keşfet',
    'Giysiler',
    'Kombinler',
    'Mankenim',
    'Profil'
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => resumePending());
    accountAction(silent: true);
    store.addListener(refresh);
    initialLoad = store.load().catchError((Object e) {
      if (mounted) setState(() => error = 'Dolap açılamadı.');
    });
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recoveryTimer?.cancel();
    billing?.dispose();
    store.removeListener(refresh);
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  void go(int i) {
    setState(() => tab = i);
    if (i == 4) unawaited(accountAction(silent: true));
  }

  void notify(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: SmText(text)));
  Widget heading(String title, String subtitle) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SmText(title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SmText(subtitle, style: const TextStyle(color: Color(0xFFBDB1CB)))
      ]));
  Widget feature(
          String title, String subtitle, String asset, VoidCallback onTap) =>
      Material(
          key: Key('feature-$asset'),
          color: const Color(0x99FFF0FA),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0x99FFFFFF))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(children: [
                    Expanded(
                        child: FractionallySizedBox(
                            widthFactor: asset == 'separate'
                                ? .79
                                : asset == 'wardrobe'
                                    ? .81
                                    : .95,
                            alignment: asset == 'separate'
                                ? Alignment.centerLeft
                                : Alignment.center,
                            child: Image.asset('assets/home/$asset.webp',
                                fit: BoxFit.contain))),
                    SmText(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.6)),
                    const SizedBox(height: 5),
                    SmText(subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, height: 1.25)),
                    const SizedBox(height: 8),
                  ]))));
  Widget discover() => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 540.0);
        final heroHeight = width * .43 + 48;
        final cardHeight =
            ((constraints.maxHeight - heroHeight - 36) / 2).clamp(96.0, 300.0);
        return ListView(
            key: const Key('discover-page'),
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 24),
            children: [
              SizedBox(
                  height: heroHeight,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                        right: -11,
                        top: 0,
                        width: width * .6125,
                        child: Image.asset('assets/home/model.webp')),
                    Positioned(
                        left: -11,
                        right: width * .43,
                        bottom: 0,
                        height: heroHeight * .3,
                        child: Image.asset('assets/home/wave.webp',
                            fit: BoxFit.fill)),
                    if (!hasPending)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: SizedBox(
                            height: 48,
                            child: Row(children: [
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                      'assets/stylemuse-icon.png',
                                      width: 32)),
                              const SizedBox(width: 8),
                              const Expanded(
                                  child: SmText('StyleMuse AI',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18))),
                              TextButton.icon(
                                  key: const Key('token-packs'),
                                  onPressed: tokenPacks,
                                  style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFF753978),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10)),
                                  icon: const Icon(Icons.workspace_premium,
                                      size: 15),
                                  label: const SmText('Stil Jetonu',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700))),
                            ])),
                      ),
                    const Positioned(
                        left: 16,
                        top: 56,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SmText('Yapay Zekâ ile',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FontStyle.italic)),
                              SmText('Stilini Keşfet',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 29,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FontStyle.italic)),
                              SizedBox(height: 18),
                              SmText(
                                  'Kıyafetlerini ayır, üzerinde dene,\nrahat kombinler oluştur.',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      height: 1.3)),
                            ])),
                  ])),
              SizedBox(
                  height: cardHeight,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: feature(
                                'Kıyafetleri Ayır',
                                'Tek fotoğraftan\nbirden fazla ürün çıkar',
                                'separate', () {
                          go(1);
                          extractPhoto();
                        })),
                        const SizedBox(width: 8),
                        Expanded(
                            child: feature(
                                'AI ile Giydir',
                                'Kıyafetleri üzerinde dene',
                                'tryon',
                                () => go(3)))
                      ])),
              const SizedBox(height: 8),
              SizedBox(
                  height: cardHeight,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: feature(
                                'Kombin Önerileri',
                                'Tarzına uygun kombinler oluştur',
                                'outfits',
                                () => go(2))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: feature(
                                'Dolabını Oluştur',
                                'Kendi kıyafet koleksiyonunu hazırla',
                                'wardrobe',
                                () => go(1)))
                      ])),
            ]);
      });
  String tr(String text) => translate(text, store.language);
  bool busy = false;
  Future<Uint8List?> selectPhoto({bool crop = true}) async {
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheet) => LocalStrings(
            language: store.language,
            child: SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const SmText('Kamera'),
                  onTap: () => Navigator.pop(sheet, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const SmText('Galeri'),
                  onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
            ]))));
    if (source == null) return null;
    final bytes = widget.pickPhoto != null
        ? await widget.pickPhoto!(source)
        : await (await ImagePicker().pickImage(
                source: source,
                maxWidth: 2400,
                maxHeight: 2400,
                imageQuality: 92))
            ?.readAsBytes();
    if (bytes == null || !mounted) return null;
    if (bytes.length > 20 * 1024 * 1024)
      throw const FormatException('Fotoğraf çok büyük.');
    return crop
        ? Navigator.push<Uint8List>(
            context,
            MaterialPageRoute(
                builder: (_) => PhotoCropPage(bytes: bytes, tr: tr)))
        : bytes;
  }

  Future<String?> chooseCategory({String initial = 'Üst giyim'}) {
    var chosen = initial;
    return showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => LocalStrings(
            language: store.language,
            child: StatefulBuilder(
                builder: (context, update) => SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const SmText('Bu parça nedir?',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, children: [
                            for (final c in wardrobeCategories)
                              ChoiceChip(
                                  label: SmText(c),
                                  selected: chosen == c,
                                  onSelected: (_) => update(() => chosen = c))
                          ]),
                          const SizedBox(height: 16),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                  key: const Key('save-garment'),
                                  onPressed: () => Navigator.pop(sheet, chosen),
                                  child: const SmText('Kaydet'))),
                        ]))))));
  }

  Future<void> addPhoto() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final bytes = await selectPhoto();
      if (bytes == null || !mounted) return;
      final category = await chooseCategory(initial: addCategory);
      if (category == null) return;
      await store.addGarment(
          image: 'data:image/jpeg;base64,${base64Encode(bytes)}',
          category: category);
      if (mounted) setState(() => filter = 'Tümü');
    } catch (_) {
      if (mounted)
        notify(tr(
            'Kıyafet kaydedilemedi. Telefonun depolama alanını kontrol et.'));
    } finally {
      if (mounted) setState(() => busy = false);
      await refreshPending();
    }
  }

  Future<bool> confirm(String message, {String label = 'Onayla'}) async =>
      await showDialog<bool>(
          context: context,
          builder: (dialog) => LocalStrings(
              language: store.language,
              child: AlertDialog(
                  title: const SmText('StyleMuse'),
                  content: SmText(message),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const SmText('Vazgeç')),
                    FilledButton(
                        key: const Key('confirm-action'),
                        onPressed: () => Navigator.pop(dialog, true),
                        child: SmText(label))
                  ]))) ??
      false;
  Future<void> garmentAction(ClosetItem item, String action) async {
    try {
      if (action == 'category') {
        final value = await chooseCategory(initial: item.category);
        if (value != null) await store.editGarment(item.id, category: value);
      }
      if (action == 'delete' &&
          await confirm('Kıyafet silinsin mi?', label: 'Sil'))
        await store.deleteGarment(item.id);
    } catch (_) {
      if (mounted) notify(tr('Kaydedilemedi.'));
    }
  }

  Future<bool> confirmTokens(int tokens) async =>
      await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialog) => LocalStrings(
              language: store.language,
              child: AlertDialog(
                  title: SmText('$tokens Stil Jetonu'),
                  content: const SmText(
                      'Bu işlem Stil Jetonu kullanır. Devam etmek istiyor musun?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const SmText('Vazgeç')),
                    FilledButton(
                        key: const Key('confirm-tokens'),
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const SmText('Onayla'))
                  ]))) ??
      false;
  Future<void> openReview() async {
    if (reviewOpen) return;
    reviewOpen = true;
    try {
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => LargeAnalysisReviewPage(
                  store: store,
                  workflow: workflow,
                  confirmTokens: confirmTokens,
                  manualCrop: () async {
                    final source = store.review?['sourceImage'];
                    if (source is! String || !safeImage(source)) return;
                    final cropped = await Navigator.push<Uint8List>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PhotoCropPage(
                                bytes: base64Decode(source.split(',').last),
                                tr: tr)));
                    if (cropped == null || !mounted) return;
                    final category = await chooseCategory(initial: addCategory);
                    if (category == null) return;
                    await store.addGarment(
                        image:
                            'data:image/jpeg;base64,${base64Encode(cropped)}',
                        category: category);
                  })));
    } finally {
      reviewOpen = false;
      await refreshPending();
    }
  }

  Future<void> recoverOperation() async {
    if (busy) return;
    recoveryTimer?.cancel();
    setState(() {
      busy = true;
      operationError = null;
    });
    try {
      final result = await workflow.recover();
      if (result == null) {
        if (mounted) notify(tr('Kurtarılacak işlem yok.'));
        return;
      }
      final pending = workflow.pending!;
      if (pending['phase'] != 'done') {
        recoveryTimer = Timer(const Duration(seconds: 4), () {
          if (mounted &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.paused) resumePending();
        });
        return;
      }
      switch (pending['action']) {
        case 'detect':
          if (result['items'] is! List)
            throw const FormatException('Invalid analysis');
          final source =
              pending['inputs'] is Map ? pending['inputs']['image'] : null;
          await store.saveReview({
            ...result,
            if (source is String && safeImage(source)) 'sourceImage': source
          });
          if (mounted) setState(() => croppedAnalysisPhoto = null);
          await workflow.acknowledge();
          if (mounted) await openReview();
        case 'generate':
          final review = store.review;
          final inputs = Map<String, dynamic>.from(pending['inputs'] as Map);
          if (review == null ||
              review['job_id'] != inputs['job_id'] ||
              result['items'] is! List) {
            throw const FormatException('Missing matching review');
          }
          await store.applyReviewEnhancement(result,
              itemIds: (inputs['item_ids'] as List).cast<String>());
          await workflow.acknowledge();
          if (mounted) await openReview();
        case 'tryon':
          if (result['state'] == 'failed')
            throw const StyleMuseApiException('tryon_failed');
          await store.saveTryOn(await loadTryOnImage(result['image']));
          await workflow.acknowledge();
          if (mounted) setState(() => tab = 3);
        default:
          throw const FormatException('Unsupported pending operation');
      }
    } catch (e) {
      if (mounted) await notifyOperationError(e);
    } finally {
      if (mounted) setState(() => busy = false);
      await refreshPending();
    }
  }

  Uint8List? croppedAnalysisPhoto;
  bool analyzingPhoto = false;

  Future<void> extractPhoto({bool usePreview = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      operationError = null;
      analysisFeedback = usePreview;
    });
    try {
      if (store.review != null) {
        await openReview();
        return;
      }
      if (!usePreview) {
        final bytes = await selectPhoto();
        if (bytes == null || !mounted) return;
        setState(() => croppedAnalysisPhoto = bytes);
        return;
      }
      final bytes = croppedAnalysisPhoto;
      if (bytes == null) return;
      await accountAction();
      if (!mounted) return;
      final result = await workflow.extract(
          'data:image/jpeg;base64,${base64Encode(bytes)}',
          confirm: (quote) async {
            final approved = await confirmTokens(quote);
            if (approved && mounted) setState(() => analyzingPhoto = true);
            return approved;
          });
      if (mounted) setState(() => analyzingPhoto = false);
      if (result == null || !mounted) return;
      if (result['items'] is! List)
        throw const FormatException('Invalid analysis');
      await store.saveReview({
        ...result,
        'sourceImage': 'data:image/jpeg;base64,${base64Encode(bytes)}'
      });
      if (mounted) setState(() => croppedAnalysisPhoto = null);
      await workflow.acknowledge();
      if (mounted) await openReview();
    } catch (e) {
      if (mounted) {
        setState(() => analyzingPhoto = false);
        await notifyOperationError(e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
      await refreshPending();
    }
  }

  Future<void> notifyOperationError(Object e) async {
    await refreshPending();
    if (!mounted) return;
    setState(() => operationError = apiError(e));
  }

  String apiError(Object e) {
    if (e is StyleMuseApiException) {
      if (e.code == 'sign_in_required')
        return tr('AI analizi için Google hesabınla giriş yap.');
      // Provider funding and account tokens are separate ledgers. Older
      // servers returned 402 for both, so inspect the reason before status.
      if (e.code == 'provider_credit_unavailable')
        return tr('Analiz için sağlayıcı kredisi doğrulanamadı.');
      if (e.code == 'provider_credit_insufficient')
        return tr('Sağlayıcı kredisi yetersiz. Hesap jetonların korunuyor.');
      if (e.code == 'style_tokens_empty' || e.code == 'insufficient_tokens')
        return tr('Bu işlem için yeterli Stil Jetonu yok.');
      if (e.status == 403)
        return tr('Bu işlem için hesap yetkisi doğrulanamadı.');
      if (e.status == 502 || e.status == 503)
        return tr('AI sağlayıcısına şu anda ulaşılamıyor.');
      if (e.code.contains('pending') || e.code.contains('ambiguous'))
        return tr('İşlemi kurtar. Yeniden gönderme yapılmadı.');
      if (e.status == 401) return tr('Lütfen yeniden giriş yap.');
    }
    return tr(hasPending
        ? 'İşlem tamamlanamadı. Kurtar düğmesiyle kontrol et.'
        : 'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.');
  }

  Widget pageHero(String title, String subtitle, String asset,
          {Key? key, String? count}) =>
      Container(
          key: key,
          height: count == null ? 126 : 142,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [
                Color(0xFF492158),
                Color(0xFF81417D),
                Color(0xFFD898B3)
              ])),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 43,
                child: Image.asset('assets/home/wave.webp', fit: BoxFit.fill)),
            Positioned(
                right: 7,
                top: 15,
                bottom: 15,
                width: 156,
                child: Image.asset('assets/home/$asset.webp',
                    fit: BoxFit.contain)),
            Padding(
                padding: const EdgeInsets.all(17),
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                        width: 185,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SmText(title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 31,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.2)),
                              const SizedBox(height: 8),
                              SmText(subtitle,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      height: 1.4)),
                              if (count != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 2),
                                        decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.white54),
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        child: SmText(count,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11)))),
                            ])))),
          ]));
  Widget operationFeedback() => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Card(
                          color: const Color(0xFFF3DDF0),
                          child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                if (busy ||
                                    (hasPending && operationError == null))
                                  const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: SmText(operationError ??
                                        (busy
                                            ? 'İşlem kontrol ediliyor…'
                                            : 'İşlemin güvenle saklandı. Yeniden gönderilmez.'))),
                                if (hasPending)
                                  TextButton(
                                      key: const Key('recover-operation'),
                                      onPressed: busy ? null : recoverOperation,
                                      child: const SmText('Kurtar')),
                              ])),
                        ));

  Widget wardrobe() {
    final showFeedback = pendingAction != 'tryon' && (hasPending || operationError != null);
    final belowAnalysis = analysisFeedback && croppedAnalysisPhoto != null;
    final visible = store.items
        .where((x) => filter == 'Tümü' || x.category == filter)
        .toList();
    return SingleChildScrollView(
        key: const Key('wardrobe-page'),
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          pageHero(
              'Giysiler',
              'Dolabındaki parçaları düzenle ve yeni kıyafetler ekle.',
              'wardrobe',
              key: const Key('wardrobe-hero'),
              count: '${store.items.length} parça'),
          const SmText('✦ Tek fotoğraftan birden fazla kıyafet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          FilledButton.icon(
              key: const Key('extract-photo'),
              onPressed: busy ? null : extractPhoto,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: SmText(store.review == null
                  ? 'Yapay zekâ ile kıyafetleri ayır'
                  : 'Önce seçtiğin parçaları incele.')),
          if (showFeedback && !belowAnalysis) operationFeedback(),
          const SizedBox(height: 5),
          const SmText(
              'Yapay zekâ fotoğraftaki kıyafetleri bulur ve ayrı ayrı önerir. Kaydetmeden önce kontrol edebilirsin.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF70566E), height: 1.45)),
          if (croppedAnalysisPhoto != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                    height: 280,
                    child: ProcessingPhoto(
                        active: analyzingPhoto,
                        stage: tr('Fotoğraf analiz ediliyor…'),
                        child: Image.memory(croppedAnalysisPhoto!,
                            fit: BoxFit.contain)))),
            FilledButton(
                onPressed: busy ? null : () => extractPhoto(usePreview: true),
                child: SmText(
                    analyzingPhoto ? 'Fotoğraf analiz ediliyor…' : 'AI ile analiz et')),
            if (showFeedback && belowAnalysis) operationFeedback(),
          ],
          const Divider(height: 12),
          const SmText('Dolaba Kıyafet Ekleme',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
              initialValue: addCategory,
              decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              items: [
                for (final category in wardrobeCategories)
                  DropdownMenuItem(value: category, child: SmText(category))
              ],
              onChanged: (value) {
                if (value != null) setState(() => addCategory = value);
              }),
          const SizedBox(height: 5),
          FilledButton.icon(
              key: const Key('manual-add'),
              onPressed: busy ? null : addPhoto,
              icon: const Icon(Icons.add, size: 18),
              label: const SmText('Fotoğraf seç ve dolabıma ekle')),
          const SizedBox(height: 8),
          const SmText(
              'Fotoğrafı seçince kıyafete odaklanacak şekilde kırpabilirsin. Yalnızca bu cihazda saklanır.',
              style: TextStyle(
                  color: Color(0xFF70566E), fontSize: 12, height: 1.5)),
          const Divider(height: 20),
          SizedBox(
              height: 45,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final category in ['Tümü', ...wardrobeCategories])
                  Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilterChip(
                          label: SmText(category),
                          selected: filter == category,
                          onSelected: (_) => setState(() => filter = category)))
              ])),
          if (visible.isEmpty)
            Container(
                margin: const EdgeInsets.only(top: 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                    color: const Color(0x99FFFAFD),
                    border: Border.all(color: const Color(0xFFE4CCE2)),
                    borderRadius: BorderRadius.circular(18)),
                child: const Column(children: [
                  Icon(Icons.favorite_border,
                      size: 36, color: Color(0xFF54265F)),
                  SizedBox(height: 12),
                  SmText('Dolabın seni bekliyor',
                      style: TextStyle(fontFamily: 'serif', fontSize: 25)),
                  SizedBox(height: 15),
                  SmText('İlk parçanı ekleyerek başlayabilirsin.',
                      style: TextStyle(fontSize: 16, color: Color(0xFF8A7886)))
                ])),
          LayoutBuilder(
              builder: (context, constraints) =>
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    for (var i = 0; i < visible.length; i++)
                      SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          height: 250,
                          child: Builder(builder: (_) {
                            final item = visible[i];
                            return Card(
                                child: Column(children: [
                              Expanded(
                                  child: SizedBox(
                                      width: double.infinity,
                                      child: GalleryPhoto(item.image))),
                              ListTile(
                                  dense: true,
                                  title: SmText(item.category),
                                  trailing: PopupMenuButton<String>(
                                      key: Key('garment-menu-$i'),
                                      onSelected: (action) =>
                                          garmentAction(item, action),
                                      itemBuilder: (_) => [
                                            PopupMenuItem(
                                                value: 'category',
                                                child: SmText(tr('Kategori'))),
                                            PopupMenuItem(
                                                value: 'delete',
                                                child: SmText(tr('Sil')))
                                          ]))
                            ]));
                          }))
                  ])),
        ]));
  }

  Future<void> tokenPacks() async {
    if (signedInUser != null && (billing == null || billing!.products.isEmpty)) await prepareBilling();
    if (!mounted) return;
    final controller = billing;
    final changes = controller ?? const AlwaysStoppedAnimation<double>(0);
    var selected = 10;
    const packs = [(200, 2000), (10, 300), (25, 625), (50, 1000), (100, 1500)];
    String price(double amount) {
      final value = amount.toStringAsFixed(2);
      return 'USD ${store.language == 'tr' ? value.replaceAll('.', ',') : value}';
    }
    String unitPrice(int count, int cents) {
      final p = controller?.productFor(count);
      if (p != null) return '${p.currencyCode} ${(p.rawPrice / count).toStringAsFixed(2)}';
      return price(cents / count / 100);
    }
    await showDialog<void>(
      context: context,
      builder: (dialog) => LocalStrings(
        language: store.language,
        child: StatefulBuilder(builder: (context, update) => ListenableBuilder(listenable: changes, builder: (context, _) {
          final product = controller?.productFor(selected);
          final enabled = product != null && product.price.trim().isNotEmpty &&
              ['ready', 'credited', 'cancelled', 'launch_failed'].contains(controller?.state);
          return Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF492158), Color(0xFFA369A0)]),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(18),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(child: SmText('Stil Jetonu Al',
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold))),
                    IconButton(
                      tooltip: tr('Kapat'),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(dialog),
                      icon: const Icon(Icons.close),
                    ),
                  ]),
                  const SmText('Uygulama ücretsiz. Yapay zekâ işlemleri jetonla kullanılır.'),
                  const SizedBox(height: 8),
                  const SmText('Ayırma · Fotoğraf başına 1 jeton'),
                  const SmText('Giydirme · Parça başına 1 jeton'),
                  const SmText('İyileştirme · Parça başına 2 jeton'),
                  const SizedBox(height: 12),
                  for (final pack in packs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: selected == pack.$1 ? const Color(0x45FFFFFF) : const Color(0x20FFFFFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: pack.$1 == 200
                            ? const Color(0xFFF5D68E) : Colors.transparent),
                        ),
                        child: ListTile(
                          selected: selected == pack.$1,
                          onTap: () => update(() => selected = pack.$1),
                          leading: Icon(selected == pack.$1
                            ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: Colors.white),
                          title: SmText('${pack.$1} jeton', style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('${unitPrice(pack.$1, pack.$2)} ${tr('/ jeton')}'
                            '${pack.$1 == 200 ? ' · ${tr('En iyi teklif')}' : ''}',
                            style: const TextStyle(color: Colors.white)),
                          trailing: Text(controller?.productFor(pack.$1)?.price ?? price(pack.$2 / 100), style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  FilledButton(key: Key(enabled ? 'purchase-enabled' : 'purchase-disabled'), onPressed: enabled ? () => controller!.buy(product) : null,
                    child: SmText('Satın al')),
                  if (controller?.state == 'credited')
                    const SmText('Jetonlar hesabına eklendi.')
                  else if (controller?.state == 'launch_failed')
                    const SmText('Google Play açılamadı. Tekrar dene.')
                  else if (controller?.state == 'retry_required')
                    TextButton(onPressed: controller!.recover, child: const SmText('Tekrar dene'))
                  else if (controller?.state == 'pending' || controller?.state == 'launching')
                    const SmText('Google Play ödemesi bekleniyor.')
                  else if (!enabled) const SmText('Satın alma henüz kullanıma açık değil.', textAlign: TextAlign.center),
                ],
              )),
            ),
          ),
        ); })),
      ),
    );
  }

  Future<void> openAdminSettings() async {
    // Visibility is not authorization: also reject direct/stale callbacks.
    if (accountBusy ||
        account?['user'] is! Map ||
        (account!['user'] as Map)['admin'] != true) return;
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => LocalStrings(
              language: store.language,
              child: AdminPage(
                  api: StyleMuseAdminApi(api),
                  importProducts: () async {
                    await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BackupPage(store: store)));
                  })),
        ));
  }

  Future<void> accountAction(
      {bool signIn = false, bool logout = false, bool silent = false}) async {
    if (accountBusy) return;
    setState(() => accountBusy = true);
    try {
      if (logout) {
        billing?.dispose();
        billing = null;
        // Clear visible identity before any network/plugin work can fail.
        if (mounted) {
          setState(() => account = null);
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        try {
          await api.logout();
        } finally {
          await googleAccountSignOut();
        }
      } else {
        final next = signIn
            ? await googleAccountSignIn(api)
            : silent
                ? await api.restoreAccount()
                : await api.account();
        if (mounted && next != null) {
          final nextUser = next['user'];
          if (nextUser is! Map || nextUser['id'] != signedInUser?['id']) {
            billing?.dispose();
            billing = null;
            plannedItems = null;
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          setState(() => account = next);
        }
      }
    } catch (e) {
      if (mounted &&
          e is StyleMuseApiException &&
          (e.status == 401 || e.code == 'session_changed')) {
        billing?.dispose();
        billing = null;
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => account = null);
      }
      if (mounted && !silent)
        notify(tr(e is StyleMuseApiException
            ? switch (e.code) {
                'google_oauth_configuration_error' =>
                  'Google Android giriş yapılandırması hatalı. Uygulama imzası ve OAuth istemcisi kontrol edilmeli.',
                'google_android_not_configured' ||
                'google_sign_in_not_configured' =>
                  'Google girişi henüz yapılandırılmadı.',
                'google_network_error' ||
                'api_network_error' ||
                'api_timeout' =>
                  'Bağlantı kurulamadı. Lütfen tekrar dene.',
                _ => signIn && e.status == 404
                    ? 'Sunucuda Android Google girişi henüz hazır değil.'
                    : 'Google bağlantısı tamamlanamadı. Lütfen tekrar dene.'
              }
            : 'Bağlantı kurulamadı. Lütfen tekrar dene.'));
    } finally {
      if (mounted) setState(() => accountBusy = false);
    }
  }

  Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 15, 0, 7),
      child: SmText(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Color(0xFF85478A))));
  Widget settingsCard(List<Widget> children) => Container(
      decoration: BoxDecoration(
          color: const Color(0xB3FFFAFD),
          border: Border.all(color: const Color(0xFFE4CCE2)),
          borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Material(
          color: Colors.transparent,
          child:
              ListTileTheme(dense: true, child: Column(children: children))));
  Future<void> savePersonalProfile(Map<String, String> values) async {
    final prefix = accountProfilePrefix;
    final owner = signedInUser?['id'];
    if (prefix == null ||
        owner is! String ||
        values.keys
            .any((key) => key != '${prefix}name' && key != '${prefix}photo')) {
      throw const StyleMuseApiException('session_changed');
    }
    final next = Map<String, String>.of(values);
    final image = next['${prefix}photo'];
    String? uploaded;
    if (image != null &&
        image.startsWith('data:') &&
        !NativeAvatarApi.validPhoto(image)) {
      throw const StyleMuseApiException('invalid_avatar');
    }
    if (image != null &&
        image != NativeAvatarApi.restoredPhoto(account!, ownerId: owner) &&
        NativeAvatarApi.validPhoto(image)) {
      uploaded = await NativeAvatarApi(api).upload(image, ownerId: owner);
      next['${prefix}photo'] = uploaded;
    }
    if (!mounted || accountProfilePrefix != prefix) {
      throw const StyleMuseApiException('session_changed');
    }
    await store.updateProfile(next);
    if (mounted && accountProfilePrefix == prefix && uploaded != null) {
      setState(() => account = {
            ...account!,
            'user': {...signedInUser!, 'avatar': uploaded},
          });
    }
  }

  Future<void> editCardAvatar() async {
    final prefix = accountProfilePrefix;
    if (prefix == null || accountBusy) return;
    try {
      final bytes = await selectPhoto();
      if (bytes == null || !mounted || accountProfilePrefix != prefix) return;
      await savePersonalProfile(
          {'${prefix}photo': 'data:image/jpeg;base64,${base64Encode(bytes)}'});
    } catch (_) {
      if (mounted) notify(tr('Kaydedilemedi.'));
    }
  }

  Widget profilePage() => LayoutBuilder(builder: (context, c) {
        final balance = int.tryParse('${account?['balance'] ?? 0}') ?? 0;
        final content = Padding(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                      key: const Key('profile-identity'),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF492158), Color(0xFFA369A0)]),
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(children: [
                        Row(children: [
                          InkWell(
                              key: const Key('edit-profile-avatar'),
                              onTap: signedInUser == null || accountBusy
                                  ? null
                                  : editCardAvatar,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: photo(
                                      accountDisplayPhoto ??
                                          'assets/profile-avatar.webp',
                                      width: 66,
                                      height: 66))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                SmText(accountDisplayName ?? 'Profil',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'serif',
                                        fontSize: 23,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                SmText(
                                    balance >= 1 ? 'Premium plan' : 'Ücretsiz plan',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                                const SizedBox(height: 5),
                                SmText(
                                    '$balance Stil Jetonu ›',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700))
                              ])),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset('assets/stylemuse-icon.png',
                                  width: 66, height: 66))
                        ]),
                        const SizedBox(height: 14),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                                onPressed: tokenPacks,
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B194B)),
                                icon: const Icon(Icons.auto_awesome, size: 16),
                                label: const SmText('Stil Jetonu Al'))),
                      ])),
                  const SizedBox(height: 10),
                  settingsCard([
                    Row(children: [
                      const SizedBox(width: 10),
                      TextButton.icon(
                          onPressed: accountBusy
                              ? null
                              : () => accountAction(
                                  signIn: account?['user'] == null,
                                  logout: account?['user'] != null),
                          icon: Icon(
                              account?['user'] == null
                                  ? Icons.login
                                  : Icons.logout,
                              size: 18),
                          label: SmText(account?['user'] == null
                              ? 'Google ile giriş yap'
                              : 'Çıkış yap')),
                      const Spacer(),
                      IconButton(
                          key: const Key('account-refresh'),
                          tooltip: tr('Yenile'),
                          onPressed: accountBusy ? null : accountAction,
                          icon: const Icon(Icons.refresh, size: 20))
                    ]),
                    if (account?['user'] is Map)
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                              (account!['user'] as Map)['email'] as String? ??
                                  ''))
                  ]),
                  if (account?['user'] is Map &&
                      (account!['user'] as Map)['admin'] == true)
                    settingsCard([
                      ListTile(
                        leading:
                            const Icon(Icons.admin_panel_settings_outlined),
                        title: const SmText('Yönetici ayarları ve bildirimler'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: openAdminSettings,
                      ),
                    ]),
                  sectionLabel('KİŞİSEL'),
                  settingsCard([
                    ListTile(
                        leading:
                            const Icon(Icons.auto_awesome_outlined, size: 21),
                        title: const SmText('Stil Profilim'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => ProfileEditor(store: store)))),
                    const Divider(height: 1),
                    ListTile(
                        leading: const Icon(Icons.person_outline, size: 21),
                        title: const SmText('Bilgilerim'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: accountBusy || signedInUser == null
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => ProfileEditor(
                                          store: store,
                                          personal: true,
                                          savePersonal: savePersonalProfile,
                                          profilePrefix:
                                              accountProfilePrefix ?? '',
                                          initialName: accountDisplayName,
                                          initialPhoto: accountDisplayPhoto,
                                          pickPhoto: () async {
                                            final bytes = await selectPhoto();
                                            return bytes == null
                                                ? null
                                                : 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                          },
                                        )))),
                  ]),
                  sectionLabel('GÖRÜNÜM'),
                  settingsCard([
                    ListTile(
                        title: const SmText('Uygulama dili'),
                        trailing: DropdownButton<String>(
                            key: const Key('app-language'),
                            value: store.language,
                            underline: const SizedBox.shrink(),
                            items: [
                              for (final pair in const {
                                'tr': '🇹🇷 Türkçe',
                                'en': '🇬🇧 English',
                                'de': '🇩🇪 Deutsch',
                                'ru': '🇷🇺 Русский',
                                'ar': '🇸🇦 العربية',
                                'fr': '🇫🇷 Français',
                                'hi': '🇮🇳 हिन्दी',
                                'zh': '🇨🇳 简体中文',
                                'ja': '🇯🇵 日本語'
                              }.entries)
                                DropdownMenuItem(
                                    value: pair.key, child: Text(pair.value))
                            ],
                            onChanged: busy
                                ? null
                                : (value) async {
                                    try {
                                      await store
                                          .updateProfile({}, language: value);
                                    } catch (_) {
                                      if (mounted) notify(tr('Kaydedilemedi.'));
                                    }
                                  })),
                  ]),
                  sectionLabel('VERİLER'),
                  settingsCard([
                    ListTile(
                        leading:
                            const Icon(Icons.file_download_outlined, size: 21),
                        title: const SmText('Veri yedekleme'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => BackupPage(store: store))))
                  ]),
                ]));
        return c.maxWidth > 600 && c.maxHeight < 650
            ? SingleChildScrollView(
                key: const Key('profile-page'),
                child: SizedBox(
                    width: c.maxWidth,
                    height: c.maxHeight,
                    child: FittedBox(
                        alignment: Alignment.topCenter,
                        fit: BoxFit.scaleDown,
                        child: SizedBox(width: c.maxWidth, child: content))))
            : SingleChildScrollView(
                key: const Key('profile-page'), child: content);
      });
  Widget outfits() {
    final idea = showIdeas ? outfitIdea : const <ClosetItem>[];
    return CustomScrollView(
        key: const Key('outfits-page'),
        slivers: [SliverPadding(padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
          sliver: SliverList(delegate: SliverChildListDelegate([
          pageHero('Kombinler',
              'Günün planına ve tarzına göre bir kombin oluştur.', 'outfits',
              key: const Key('outfits-hero')),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const SmText('Bugünkü planın',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF70566E))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                      initialValue: outfitPlan,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10)),
                      items: [
                        for (final value in [
                          'Günlük',
                          'İş / Ofis',
                          'Akşam yemeği',
                          'Özel davet'
                        ])
                          DropdownMenuItem(
                              value: value,
                              child: SmText(value,
                                  style: const TextStyle(fontSize: 13)))
                      ],
                      onChanged: (v) => setState(() {
                            outfitPlan = v!;
                            ideaOffset = 0;
                          }))
                ])),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const SmText('Hangi tarz?',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF70566E))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                      initialValue: outfitStyle,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10)),
                      items: [
                        for (final value in [
                          'Rahat ve şık',
                          'Minimal',
                          'Romantik',
                          'Modern klasik'
                        ])
                          DropdownMenuItem(
                              value: value,
                              child: SmText(value,
                                  style: const TextStyle(fontSize: 13)))
                      ],
                      onChanged: (v) => setState(() {
                            outfitStyle = v!;
                            ideaOffset = 0;
                          }))
                ])),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: () => setState(() {
                    if (showIdeas) ideaOffset++;
                    showIdeas = true;
                  }),
              icon: const Icon(Icons.auto_awesome, size: 16),
              iconAlignment: IconAlignment.end,
              label: const SmText('Bana fikir ver')),
          if (showIdeas)
            Column(key: const Key('outfit-recommendations'), children: [
              if (idea.isEmpty)
                const SmText(
                    'Kombin için üst ve alt giyim ya da elbise seçmelisin.'),
              if (idea.isNotEmpty)
                Card(
                    child: Column(children: [
                  Row(children: [
                    for (final item in idea)
                      Expanded(
                          child: SizedBox(
                              height: 110,
                              child: KeyedSubtree(
                                  key: ValueKey('outfit-idea-${item.id}'),
                                  child:
                                      GalleryPhoto(item.image))))
                  ]),
                  FilledButton(
                      onPressed: () => setState(() {
                            plannedItems = idea.map((i) => i.id).toList();
                            tab = 3;
                          }),
                      child: const SmText('Seç ve giydir')),
                ])),
            ]),
          const SizedBox(height: 10),
          const SmText('Kaydettiğim kombinler',
              style: TextStyle(
                  fontFamily: 'serif', fontSize: 25, letterSpacing: -1)),
          ]))),
          SliverPadding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              sliver: SavedLooksGrid(store: store)),
        ]);
  }

  @override
  Widget build(BuildContext context) => LocalStrings(
      language: store.language,
      child: Directionality(
          textDirection:
              store.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            extendBodyBehindAppBar: false,
            body: Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: tab == 0
                            ? const [
                                Color(0xFF753A77),
                                Color(0xFFB77FAE),
                                Color(0xFFDAC1D8)
                              ]
                            : const [
                                Color(0xFFEDDDF3),
                                Color(0xFFFAF1F8),
                                Color(0xFFFFF8F9)
                              ])),
                child: SafeArea(
                    child: Column(children: [
                  if (tab == 3 && pendingAction == 'tryon' &&
                      !hasTryOnRun && (hasPending || operationError != null))
                    operationFeedback(),
                  if (error != null)
                    MaterialBanner(content: SmText(error!), actions: [
                      TextButton(
                          onPressed: () => setState(() => error = null),
                          child: const SmText('Tamam'))
                    ]),
                  Expanded(
                      child: switch (tab) {
                    0 => discover(),
                    1 => wardrobe(),
                    2 => outfits(),
                    3 => MannequinPage(
                        initialItems: plannedItems,
                        occasion: outfitPlan,
                        style: outfitStyle,
                        store: store,
                        workflow: workflow,
                        confirmTokens: confirmTokens,
                        pickPhoto: () => selectPhoto(crop: false),
                        onOpenWardrobe: () => go(1),
                        onBusy: (value) {
                          if (mounted) setState(() => busy = value);
                          refreshPending();
                        }),
                    4 => profilePage(),
                    _ => Center(
                        key: Key([
                          'discover-page',
                          'wardrobe-page',
                          'outfits-page',
                          'mannequin-page',
                          'profile-page'
                        ][tab]),
                        child: SmText(labels[tab]))
                  })
                ]))),
            bottomNavigationBar: NavigationBar(
                backgroundColor: const Color(0xFFF6E9F5),
                indicatorColor: const Color(0xFFE7CCE9),
                height: 74,
                selectedIndex: tab,
                onDestinationSelected: busy ? null : go,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationDestination(
                        icon: WebNavIcon(i, key: Key('web-nav-icon-$i')),
                        label: translate(labels[i], store.language))
                ]),
          )));
}
