import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/mannequin_page.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  for (final finish in [true, false])
    testWidgets(
        'sequential category tryon respects one total consent (finish: $finish)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final photo =
          'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
      final store = ClosetStore(memory: true);
      await store.addGarment(image: photo, category: 'Üst giyim');
      await store.addGarment(image: photo, category: 'Alt giyim');
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
        '/api/tryon/sequence': {'total': 2, 'image': photo},
      });
      final confirmations = <int>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MannequinPage(
        store: store,
        workflow: TokenWorkflowController(
            api: StyleMuseApi(storage: secure, transport: transport),
            storage: secure),
        confirmTokens: (tokens) async {
          confirmations.add(tokens);
          return finish;
        },
        pickPhoto: () async => null,
        onBusy: (_) {},
      ))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mannequin-suggest')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('tryon-start')));
      await tester.tap(find.byKey(const Key('tryon-start')));
      await tester.pumpAndSettle();
      expect(confirmations, [2]);
      final steps = transport.bodies['/api/tryon/sequence/advance'] ?? [];
      expect(steps.map((step) => step['step']), finish ? [0, 1] : []);
      final starts = transport.bodies['/api/tryon/sequence'] ?? [];
      expect(starts, hasLength(finish ? 1 : 0));
      if (finish) expect(starts.single['garments'], hasLength(2));
      expect(secure.values.containsKey(TokenWorkflowController.pendingKey),
          isFalse);
      await tester.ensureVisible(find.byKey(const Key('save-tryon')));
      await tester.tap(find.byKey(const Key('save-tryon')));
      await tester.pumpAndSettle();
      if (finish) {
        expect(
            tester
                .widget<OutlinedButton>(find.byKey(const Key('save-tryon')))
                .onPressed,
            isNull);
        expect(find.text('Kaydedildi'), findsOneWidget);
        expect(store.looks.single['itemIds'],
            store.items.map((x) => x.id).toList());
      } else {
        expect(store.looks,
            isEmpty); // Never save an incomplete multi-step render.
      }
      await tester.ensureVisible(find.byKey(const Key('mannequin-clear')));
      await tester.tap(find.byKey(const Key('mannequin-clear')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save-tryon')));
      await tester.tap(find.byKey(const Key('save-tryon')));
      await tester.pumpAndSettle();
      if (finish) {
        expect(
            tester
                .widget<OutlinedButton>(find.byKey(const Key('save-tryon')))
                .onPressed,
            isNull);
        expect(find.text('Kaydedildi'), findsOneWidget);
        expect(store.looks.single['itemIds'],
            store.items.map((x) => x.id).toList());
      } else {
        expect(store.looks, isEmpty);
      }
      expect(tester.takeException(), isNull);
    });
}
