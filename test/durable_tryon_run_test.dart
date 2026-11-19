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
        'style_tokens': 1,
        'estimated_cost_usd': 0.01
      },
      '/api/tryon': {'state': 'done', 'job_id': 'first', 'image': image},
      '/api/tryon/status': {'state': 'done', 'image': image},
    });
    var calls = 0;
    transport.replies['/api/tryon'] = {
      'state': 'pending',
      'job_id': 'pending-original'
    };
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(secure.values['stylemuse.tryon.run'], isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    api = StyleMuseApi(storage: secure, transport: transport);
    await tester
        .pumpWidget(page(TokenWorkflowController(api: api, storage: secure)));
    await tester.pumpAndSettle();
    expect(transport.paths.where((p) => p == '/api/tryon'), hasLength(1));
    expect(transport.bodies['/api/tryon/status']!.first['job_id'],
        'pending-original');
    expect(calls, 1);
    final run = jsonDecode(secure.values['stylemuse.tryon.run']!);
    expect(run['selected'], hasLength(2));
    expect(run['applied'], hasLength(1));
    expect(run['remaining'], hasLength(1));
    final save =
        tester.widget<ButtonStyleButton>(find.byKey(const Key('save-tryon')));
    expect(save.onPressed, isNull);
    transport.replies['/api/tryon'] = {
      'state': 'done',
      'job_id': 'second',
      'image': image
    };
    await tester.ensureVisible(find.byKey(const Key('tryon-start')));
    await tester.tap(find.byKey(const Key('tryon-start')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(transport.paths.where((p) => p == '/api/tryon'), hasLength(2));
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
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });
}
