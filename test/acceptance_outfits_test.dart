import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/mannequin_page.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

Future<(ClosetStore, dynamic)> setup(WidgetTester tester,
    {bool finish = true}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final photo =
      'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
  final store = ClosetStore(memory: true);
  for (final category in ['Üst giyim', 'Alt giyim', 'Elbise', 'Çanta']) {
    await store.addGarment(image: photo, category: category);
  }
  final secure = MemorySecure();
  final transport = FixtureTransport({
    '/api/session': {},
    '/api/account': {
      'user': {'provider': 'google', 'id': 'fixture'}
    },
    '/api/quote': {
      'quote_id': 'q',
      'style_tokens': 1,
      'estimated_cost_usd': 0.01
    },
    '/api/tryon': {'state': 'done', 'job_id': 'job', 'image': photo},
  });
  var confirmations = 0;
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: MannequinPage(
    store: store,
    workflow: TokenWorkflowController(
        api: StyleMuseApi(storage: secure, transport: transport),
        storage: secure),
    confirmTokens: (_) async => finish || ++confirmations == 1,
    pickPhoto: () async => null,
    onBusy: (_) {},
  ))));
  await tester.pumpAndSettle();
  return (store, tester.state(find.byType(MannequinPage)));
}

bool saveEnabled(WidgetTester tester) =>
    tester
        .widget<OutlinedButton>(find.byKey(const Key('save-tryon')))
        .onPressed !=
    null;

void main() {
  testWidgets('dress alone completes a saveable on-person outfit', (tester) async {
    final (store, state) = await setup(tester);
    state.selected['Elbise'] = store.items[2].id;
    await state.start();
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isTrue);
    await tester.ensureVisible(find.byKey(const Key('save-tryon')));
    await tester.tap(find.byKey(const Key('save-tryon')));
    await tester.pumpAndSettle();
    expect(store.looks.single['itemIds'], [store.items[2].id]);
    expect(store.looks.single['aiImage'], store.tryonResult);
  });
  testWidgets('pre-existing result without completion provenance cannot save', (tester) async {
    final (store, state) = await setup(tester);
    await store.saveTryOn(store.items.first.image);
    state.suggest();
    state.setState(() {});
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);
    expect(store.looks, isEmpty);
  });
  testWidgets('incomplete wardrobe does not recommend a partial outfit',
      (tester) async {
    final (store, state) = await setup(tester);
    store.items.removeWhere((item) => item.category != 'Üst giyim');
    state.suggest();
    expect(state.selected, isEmpty);
  });
  testWidgets('changed model cannot save a formerly complete result',
      (tester) async {
    final (store, state) = await setup(tester);
    state.suggest();
    await state.start();
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isTrue);
    await store.updateProfile({'modelPhoto': 'changed-model'});
    state.setState(() {});
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);
  });
  testWidgets('suggestions are inline selectable without navigation',
      (tester) async {
    final (_, state) = await setup(tester);
    state.suggest();
    state.setState(() {});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outfit-recommendations')), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(4));
    await tester.ensureVisible(find.byKey(const Key('recommendation-2')));
    await tester.tap(find.byKey(const Key('recommendation-2')));
    await tester.pumpAndSettle();
    expect(state.selected.containsKey('Elbise'), isTrue);
    expect(state.selected.containsKey('Üst giyim'), isFalse);
    expect(state.selected.containsKey('Alt giyim'), isFalse);
  });
  for (final finish in [true, false]) {
    testWidgets('save requires all selected steps (finish: $finish)',
        (tester) async {
      final (store, state) = await setup(tester, finish: finish);
      state.suggest();
      await state.start();
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), finish);
      if (finish) {
        await tester.ensureVisible(find.byKey(const Key('save-tryon')));
        await tester.tap(find.byKey(const Key('save-tryon')));
        await tester.pumpAndSettle();
        expect(store.looks.single['aiImage'], store.tryonResult);
        expect(store.looks.single['itemIds'], hasLength(3));
        state.selected.clear();
        state.setState(() {});
        await tester.pumpAndSettle();
        expect(saveEnabled(tester), isFalse);
      } else {
        expect(store.looks, isEmpty);
      }
    });
  }
  testWidgets('selection alone cannot save an on-person outfit',
      (tester) async {
    final (_, state) = await setup(tester);
    state.suggest();
    state.setState(() {});
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);
  });
}
