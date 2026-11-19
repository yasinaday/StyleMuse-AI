import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'crop_test_helpers.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:convert';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  testWidgets('token prices match source and purchase remains disabled',
      (tester) async {
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('token-packs')), findsOneWidget);
    await tester.tap(find.byKey(const Key('token-packs')));
    await tester.pumpAndSettle();
    expect(find.text('USD 20,00'), findsOneWidget);
    expect(find.text('USD 3,00'), findsOneWidget);
    expect(find.text('USD 6,25'), findsOneWidget);
    expect(find.text('USD 10,00'), findsOneWidget);
    expect(find.text('USD 15,00'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('purchase-disabled')))
            .onPressed,
        isNull);
  });
  testWidgets('backup settings offer export restore and double-confirmed reset',
      (tester) async {
    final store = ClosetStore(memory: true);
    await store.addGarment(
        image:
            'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 20, height: 20)))}',
        category: 'Elbise');
    await tester.pumpWidget(StyleMuseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Veri yedekleme'), findsOneWidget);
    await tester.tap(find.text('Veri yedekleme'));
    await tester.pumpAndSettle();
    expect(find.text('Verilerimi yedekle ↓'), findsOneWidget);
    expect(find.text('Yedekten geri yükle ↑'), findsOneWidget);
    await tester.tap(find.text('Dolabı sıfırla'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('backup-confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.items, hasLength(1));
    await tester.tap(find.byKey(const Key('backup-confirm')));
    await tester.pumpAndSettle();
    expect(store.items, isEmpty);
  });
  testWidgets(
      'wardrobe garment can be recategorized and deleted with confirmation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ClosetStore(memory: true);
    await store.addGarment(
        image:
            'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 20, height: 20)))}',
        category: 'Elbise');
    await tester.pumpWidget(StyleMuseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('garment-menu-0')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('garment-menu-0')));
    await tester.tap(find.byKey(const Key('garment-menu-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kategori'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Çanta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-garment')));
    await tester.pumpAndSettle();
    expect(store.items.single.category, 'Çanta');
    await tester.ensureVisible(find.byKey(const Key('garment-menu-0')));
    await tester.tap(find.byKey(const Key('garment-menu-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));
    await tester.tap(find.byKey(const Key('confirm-action')));
    await tester.pumpAndSettle();
    expect(store.items, isEmpty);
  });
  testWidgets(
      'profile language preference changes the entire shell and is saved',
      (tester) async {
    final store = ClosetStore(memory: true);
    await tester.pumpWidget(StyleMuseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    // The profile list builds the language selector lazily below the fold.
    await tester.scrollUntilVisible(
      find.byKey(const Key('app-language')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('profile-page')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-language')), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇬🇧 English').last);
    await tester.pumpAndSettle();
    expect(store.language, 'en');
    expect(find.text('Discover'), findsOneWidget);
  });
  testWidgets('style profile saves personal details and mannequin measurements',
      (tester) async {
    final store = ClosetStore(memory: true);
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture', 'name': 'Original'}
      }
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: MemorySecure(), transport: transport)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Stil Profilim'), findsOneWidget);
    await tester.tap(find.text('Stil Profilim'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-name')), findsNothing);
    await tester.enterText(find.byKey(const Key('profile-height')), '172');
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();
    expect(store.profile['height'], '172');
    await tester.tap(find.byKey(const Key('account-refresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bilgilerim'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-height')), findsNothing);
    await tester.enterText(find.byKey(const Key('profile-name')), 'Ada');
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();
    expect(store.profile['google:fixture:name'], 'Ada');
    expect(store.profile['name'], isNull);
    expect(store.profile['height'], '172');
    expect(find.text('Ada'), findsOneWidget);
  });
  testWidgets('a dress can be composed into a persistent local outfit',
      (tester) async {
    final store = ClosetStore(memory: true);
    final bytes = img.encodePng(img.Image(width: 20, height: 20));
    await store.addGarment(
        image: 'data:image/png;base64,${base64Encode(bytes)}',
        category: 'Elbise');
    await tester.pumpWidget(StyleMuseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kombinler').last);
    await tester.pumpAndSettle();
    expect(find.text('Bana fikir ver'), findsOneWidget);
    await tester.tap(find.text('Bana fikir ver'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.tap(find.byKey(const Key('save-look')));
    await tester.pumpAndSettle();
    expect(store.looks, hasLength(1));
    expect(store.looks.single['images'], hasLength(1));
    expect(find.byKey(const Key('saved-look-0')), findsOneWidget);
  });
  testWidgets('gallery photo is cropped categorized and saved locally',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ClosetStore(memory: true);
    final bytes =
        Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 60)));
    await tester
        .pumpWidget(StyleMuseApp(store: store, pickPhoto: (_) async => bytes));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fotoğraf seç ve dolabıma ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byKey(const Key('crop-confirm')));
    await waitForCropReturn(tester, find.byKey(const Key('save-garment')));
    await tester.tap(find.byKey(const Key('save-garment')));
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));
    expect(store.items.single.category, 'Üst giyim');
    expect(store.items.single.image, startsWith('data:image/jpeg;base64,'));
  });
  testWidgets('photo addition opens camera and gallery choices',
      (tester) async {
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fotoğraf seç ve dolabıma ekle'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });
  testWidgets('all nine source locales translate navigation and Arabic is RTL',
      (tester) async {
    final names = [
      'Keşfet',
      'Discover',
      'Entdecken',
      'Обзор',
      'استكشاف',
      'Découvrir',
      'खोजें',
      '探索',
      '見つける'
    ];
    for (var i = 0; i < appLanguages.length; i++) {
      final store = ClosetStore(memory: true)..language = appLanguages[i];
      await tester.pumpWidget(StyleMuseApp(key: ValueKey(i), store: store));
      await tester.pumpAndSettle();
      expect(find.text(names[i]), findsOneWidget);
      expect(Directionality.of(tester.element(find.byType(NavigationBar))),
          i == 4 ? TextDirection.rtl : TextDirection.ltr);
    }
  });
  testWidgets(
      'Discover opens the native wardrobe with category filters and add action',
      (tester) async {
    await tester.pumpWidget(const StyleMuseApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Stilini Keşfet'), findsOneWidget);
    await tester.tap(find.text('Dolabını Oluştur'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('wardrobe-page')), findsOneWidget);
    expect(find.text('Üst giyim'), findsNWidgets(2));
    expect(find.text('Fotoğraf seç ve dolabıma ekle'), findsOneWidget);
  });
  testWidgets('native shell exposes five navigable tabs', (tester) async {
    await tester.pumpWidget(const StyleMuseApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    await tester.tap(find.text('Kombinler').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outfits-page')), findsOneWidget);
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-page')), findsOneWidget);
  });
}
