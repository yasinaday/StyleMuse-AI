import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/mannequin_page.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  testWidgets(
      'ambiguous sequence stays recoverable and cannot start another paid run',
      (tester) async {
    final store = ClosetStore(memory: true);
    final secure = MemorySecure();
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture'}
      },
      '/api/tryon/sequence/status': {
        'state': 'ambiguous',
        'completed': 0,
        'total': 1
      },
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MannequinPage(
                store: store,
                workflow: TokenWorkflowController(
                    api: StyleMuseApi(storage: secure, transport: transport),
                    storage: secure),
                confirmTokens: (_) async =>
                    throw StateError('must not ask for new payment'),
                pickPhoto: () async => null,
                onBusy: (_) {}))));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(MannequinPage));
    state.sequenceId = 'original';
    state.sequenceState = 'ambiguous';
    state.sequenceItems = <String>['garment'];
    state.runOwner = 'google:fixture';
    expect(state.hasSequence, isTrue);
    await state.start();
    await tester.pumpAndSettle();
    expect(transport.paths, contains('/api/tryon/sequence/status'));
    expect(transport.paths, isNot(contains('/api/quote')));
    expect(transport.paths, isNot(contains('/api/tryon/sequence')));
  });
  testWidgets(
      'restart restores selected items completed steps and same pending job without submission',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: image, category: 'Üst giyim');
    await store.addGarment(image: image, category: 'Alt giyim');
    final secure = MemorySecure();
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture'}
      },
      '/api/quote': {
        'quote_id': 'q',
        'style_tokens': 2,
        'estimated_cost_usd': 0.01
      },
      '/api/tryon/sequence': {'total': 2, 'image': image},
    });
    var calls = 0;
    Widget page(TokenWorkflowController workflow) => MaterialApp(
        home: Scaffold(
            body: MannequinPage(
                store: store,
                workflow: workflow,
                confirmTokens: (_) async {
                  calls++;
                  return true;
                },
                pickPhoto: () async => null,
                onBusy: (_) {})));
    var api = StyleMuseApi(storage: secure, transport: transport);
    await tester
        .pumpWidget(page(TokenWorkflowController(api: api, storage: secure)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mannequin-suggest')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('tryon-start')));
    await tester.tap(find.byKey(const Key('tryon-start')));
    await tester.pumpAndSettle();
    expect(secure.values['stylemuse.tryon.run'], isNotNull);
    final run = jsonDecode(secure.values['stylemuse.tryon.run']!) as Map;
    // Recreate the locally durable checkpoint after a lost in-flight response.
    run['sequenceState'] = 'pending';
    run['applied'] = <String, String>{};
    run['image'] = null;
    run['completedInput'] = null;
    secure.values['stylemuse.tryon.run'] = jsonEncode(run);
    transport.bodies['/api/tryon/sequence/advance']!.removeLast();
    final beforeRestore =
        transport.paths.where((p) => p.endsWith('/advance')).length;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    api = StyleMuseApi(storage: secure, transport: transport);
    await tester
        .pumpWidget(page(TokenWorkflowController(api: api, storage: secure)));
    await tester.pumpAndSettle();
    expect(transport.paths.where((p) => p.endsWith('/advance')),
        hasLength(beforeRestore));
    expect(transport.bodies['/api/tryon/sequence/status']!.last['request_id'],
        run['sequenceId']);
    expect(calls, 1);
    expect(
        (jsonDecode(secure.values['stylemuse.tryon.run']!) as Map)['applied'],
        hasLength(1));
    expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('save-tryon')))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.byKey(const Key('tryon-start')));
    await tester.tap(find.byKey(const Key('tryon-start')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
        transport.bodies['/api/tryon/sequence/advance']!.map((e) => e['step']),
        [0, 1]);
    expect(jsonDecode(secure.values['stylemuse.tryon.run']!)['applied'],
        hasLength(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    api = StyleMuseApi(storage: secure, transport: transport);
    await tester
        .pumpWidget(page(TokenWorkflowController(api: api, storage: secure)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('save-tryon')))
            .onPressed,
        isNotNull);
    await tester.ensureVisible(find.byKey(const Key('save-tryon')));
    await tester.tap(find.byKey(const Key('save-tryon')));
    await tester.pumpAndSettle();
    expect(store.looks.single['itemIds'], hasLength(2));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
