import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

class RecoveryStore extends ClosetStore {
  RecoveryStore(this.secure) : super(memory: true);
  final MemorySecure secure;
  bool failSave = false;
  @override
  Future<void> saveReview(Map<String, dynamic>? data) async {
    expect(secure.values[TokenWorkflowController.pendingKey], isNotNull);
    if (failSave) throw StateError('disk full');
    await super.saveReview(data);
  }

  @override
  Future<void> saveTryOn(String? image) async {
    expect(secure.values[TokenWorkflowController.pendingKey], isNotNull);
    await super.saveTryOn(image);
  }
}

void main() {
  testWidgets(
      'failed durable save retains completed operation for explicit retry',
      (tester) async {
    final secure = MemorySecure();
    final store = RecoveryStore(secure)..failSave = true;
    secure.values[TokenWorkflowController.pendingKey] = jsonEncode({
      'owner': 'google:fixture-user',
      'action': 'detect',
      'phase': 'done',
      'inputs': {'request_id': 'original'},
      'result': {'job_id': 'job', 'items': []}
    });
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'}
      }
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recover-operation')));
    await tester.pumpAndSettle();
    expect(secure.values[TokenWorkflowController.pendingKey], isNotNull);
    expect(store.review, isNull);
    store.failSave = false;
    await tester.tap(find.byKey(const Key('recover-operation')));
    await tester.pumpAndSettle();
    expect(store.review!['job_id'], 'job');
    expect(secure.values[TokenWorkflowController.pendingKey], isNull);
    expect(
        transport.paths
            .where((p) => p != '/api/session' && p != '/api/account'),
        isEmpty);
  });
  for (final action in ['detect', 'generate', 'tryon']) {
    testWidgets('restart recovery routes $action without paid submission',
        (tester) async {
      final secure = MemorySecure();
      final store = RecoveryStore(secure);
      final image =
          'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
      if (action == 'generate')
        store.review = {
          'job_id': 'job',
          'items': [
            {'id': 'a', 'category': 'Elbise', 'preview': image},
            {'id': 'b', 'category': 'Üst giyim', 'preview': image}
          ]
        };
      secure.values[TokenWorkflowController.pendingKey] = jsonEncode({
        'owner': 'google:fixture-user',
        'action': action,
        'phase': 'submitted',
        'inputs': {
          'request_id': 'original',
          'job_id': 'job',
          'item_ids': ['a']
        }
      });
      final result = action == 'tryon'
          ? {'state': 'done', 'image': image}
          : {
              'job_id': 'job',
              'items': [
                {'id': 'a', 'image': image, 'category': 'Elbise'}
              ]
            };
      final transport = FixtureTransport({
        '/api/session': {},
        '/api/account': {
          'user': {'provider': 'google', 'id': 'fixture-user'}
        },
        '/api/operations/recover': {'state': 'done', 'result': result}
      });
      await tester.pumpWidget(StyleMuseApp(
          store: store,
          api: StyleMuseApi(storage: secure, transport: transport)));
      await tester.pumpAndSettle();
      // Restart now performs read-only recovery automatically on the scoped screen.
      expect(find.byKey(const Key('recover-operation')), findsNothing);
      expect(secure.values[TokenWorkflowController.pendingKey], isNull);
      expect(transport.paths,
          ['/api/session', '/api/account', '/api/operations/recover']);
      if (action == 'tryon') {
        expect(store.tryonResult, startsWith('data:image/'));
        expect(find.byKey(const Key('mannequin-page')), findsOneWidget);
      } else {
        expect(find.byKey(const Key('analysis-review')), findsOneWidget);
        expect(store.review!['items'], hasLength(action == 'generate' ? 2 : 1));
        if (action == 'generate')
          expect(store.review!['items'][0]['enhanced'], true);
      }
    });
  }
}
