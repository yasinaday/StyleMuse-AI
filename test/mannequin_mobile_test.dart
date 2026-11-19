import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/mannequin_page.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  testWidgets('empty wardrobe offers an add-clothes action', (tester) async {
    final store = ClosetStore(memory: true);
    final secure = MemorySecure();
    final transport = FixtureTransport({});
    final workflow = TokenWorkflowController(
        api: StyleMuseApi(storage: secure, transport: transport),
        storage: secure);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MannequinPage(
                store: store,
                workflow: workflow,
                confirmTokens: (_) async => false,
                pickPhoto: () async => null,
                onBusy: (_) {}))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('mannequin-add-clothes')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Kıyafet ekle'), findsOneWidget);
    expect(transport.paths, isEmpty);
  });

  testWidgets('native consented try-on still persists result and saved outfit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 100, height: 200)))}';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: image, category: 'Elbise');
    final secure = MemorySecure();
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'}
      },
      '/api/quote': {
        'quote_id': 'q',
        'style_tokens': 1,
        'estimated_cost_usd': 0.01
      },
      '/api/tryon/sequence': {'total': 1, 'image': image}
    });
    final workflow = TokenWorkflowController(
        api: StyleMuseApi(storage: secure, transport: transport),
        storage: secure);
    final confirmations = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MannequinPage(
                store: store,
                workflow: workflow,
                confirmTokens: (tokens) async {
                  confirmations.add(tokens);
                  return true;
                },
                pickPhoto: () async => null,
                onBusy: (_) {}))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mannequin-suggest')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('tryon-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tryon-start')));
    await tester.pumpAndSettle();
    expect(confirmations, [1]);
    expect(
        transport.paths.where((path) => path == '/api/tryon/sequence/advance'),
        hasLength(1));
    expect(store.tryonResult, isNotNull);
    expect(
        secure.values.containsKey(TokenWorkflowController.pendingKey), isFalse);
    await tester.ensureVisible(find.byKey(const Key('save-tryon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-tryon')));
    await tester.pumpAndSettle();
    expect(store.looks.single['aiImage'], store.tryonResult);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mobile web headings and action order preserve selection clear and upload',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bytes = img.encodeJpg(img.Image(width: 100, height: 200));
    final image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: image, category: 'Elbise');
    final secure = MemorySecure();
    final workflow = TokenWorkflowController(
        api: StyleMuseApi(storage: secure, transport: FixtureTransport({})),
        storage: secure);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MannequinPage(
                store: store,
                workflow: workflow,
                confirmTokens: (_) async => false,
                pickPhoto: () async => bytes,
                onBusy: (_) {}))));
    await tester.pumpAndSettle();
    expect(find.text('KOMBİN\nÖNER'), findsOneWidget);
    expect(find.text('Temizle'), findsOneWidget);
    final save = find.byKey(const Key('save-tryon'));
    final upload = find.text('Kendi fotoğrafımı yükle');
    final start = find.byKey(const Key('tryon-start'));
    expect(tester.getTopLeft(save).dy, lessThan(tester.getTopLeft(upload).dy));
    expect(tester.getTopLeft(upload).dy, lessThan(tester.getTopLeft(start).dy));
    await tester.tap(find.text('KOMBİN\nÖNER'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const Key('mannequin-slot-0')),
            matching: find.byType(Image)),
        findsOneWidget);
    await tester.tap(find.text('Temizle'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(store.items, hasLength(1));
    await tester.ensureVisible(upload);
    await tester.tap(upload);
    await tester.pumpAndSettle();
    expect(store.profile['modelPhoto'], startsWith('data:image/jpeg;base64,'));
    expect(store.tryonResult, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '390px mobile keeps chosen garment left of full-body contain model',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 100, height: 200)))}';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: image, category: 'Elbise');
    final secure = MemorySecure();
    final workflow = TokenWorkflowController(
        api: StyleMuseApi(storage: secure, transport: FixtureTransport({})),
        storage: secure);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MannequinPage(
                store: store,
                workflow: workflow,
                confirmTokens: (_) async => false,
                pickPhoto: () async => null,
                onBusy: (_) {}))));
    await tester.pumpAndSettle();
    final model = find.byKey(const Key('mannequin-preview'));
    final slot = find.byKey(const Key('mannequin-slot-0'));
    expect(slot, findsOneWidget);
    final modelRect = tester.getRect(model);
    final slotRect = tester.getRect(slot);
    expect(slotRect.right, lessThanOrEqualTo(modelRect.left));
    expect(modelRect.right, lessThanOrEqualTo(376));
    expect(modelRect.height, greaterThanOrEqualTo(400));
    final modelImage = tester.widget<Image>(
        find.descendant(of: model, matching: find.byType(Image)).first);
    expect(modelImage.fit, BoxFit.contain);
    await tester.scrollUntilVisible(find.byKey(const Key('try-garment-0')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const Key('try-garment-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('try-garment-0')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: slot, matching: find.byType(Image)),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('tryon-start')))
            .onPressed,
        isNotNull);
    await tester.ensureVisible(slot);
    await tester
        .tap(find.byKey(ValueKey('remove-selected-${store.items.single.id}')));
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));
    expect(
        find.descendant(of: slot, matching: find.byType(Image)), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
