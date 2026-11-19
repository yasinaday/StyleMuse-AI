import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'crop_test_helpers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  testWidgets('wardrobe category selection carries through native photo save',
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
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çanta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crop-confirm')));
    await waitForCropReturn(tester, find.byKey(const Key('save-garment')));
    await tester.tap(find.byKey(const Key('save-garment')));
    await tester.pumpAndSettle();
    expect(store.items.single.category, 'Çanta');
  });
  testWidgets('profile groups settings beneath gradient identity card',
      (tester) async {
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-identity')), findsOneWidget);
    for (final label in ['KİŞİSEL', 'GÖRÜNÜM', 'VERİLER']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Bilgilerim'), findsOneWidget);
    expect(find.byKey(const Key('app-language')), findsOneWidget);
  });
  testWidgets('outfits exposes illustrated hero and two planning controls',
      (tester) async {
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kombinler').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outfits-hero')), findsOneWidget);
    expect(find.text('Bugünkü planın'), findsOneWidget);
    expect(find.text('Hangi tarz?'), findsOneWidget);
    expect(find.text('Kaydettiğim kombinler'), findsOneWidget);
  });
  testWidgets(
      'wardrobe illustrates count and puts extraction before manual add',
      (tester) async {
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wardrobe-hero')), findsOneWidget);
    expect(find.text('0 parça'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('extract-photo'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('manual-add'))).dy));
    expect(find.text('Dolabın seni bekliyor'), findsOneWidget);
  });
  testWidgets('discover has four illustrated features in two columns',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    final first = find.byKey(const Key('feature-separate'));
    final second = find.byKey(const Key('feature-tryon'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(find.byKey(const Key('feature-wardrobe')), findsOneWidget);
  });
  testWidgets('recovery is hidden without stored pending operation',
      (tester) async {
    final secure = MemorySecure();
    final transport = FixtureTransport({});
    await tester.pumpWidget(StyleMuseApp(
        store: ClosetStore(memory: true),
        api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recover-operation')), findsNothing);
    expect(transport.paths, isEmpty);
  });
  testWidgets('light pink identity remains light under Android dark preference',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.light);
    expect(Theme.of(context).scaffoldBackgroundColor, const Color(0xFFFCF6FA));
  });
}
