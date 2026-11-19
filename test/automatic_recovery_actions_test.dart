import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/main.dart';

import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

import 'pending_recovery_ui_test.dart' show RecoveryStore;

void main() {
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
