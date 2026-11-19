import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  testWidgets(
      'inline plan selections reach consented tryon and rendered saved outfit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ClosetStore(memory: true);
    final image =
        'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 20, height: 30)))}';
    await store.addGarment(image: image, category: 'Elbise');
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
      '/api/tryon': {'state': 'done', 'job_id': 'job', 'image': image},
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: MemorySecure(), transport: transport)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kombinler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akşam yemeği').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Romantik').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bana fikir ver'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outfits-page')), findsOneWidget);
    await tester.ensureVisible(find.text('Seç ve giydir').first);
    await tester.tap(find.text('Seç ve giydir').first);
    await tester.pumpAndSettle();
    expect(store.looks, isEmpty);
    expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('save-tryon')))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.byKey(const Key('tryon-start')));
    await tester.tap(find.byKey(const Key('tryon-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm-tokens')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-tryon')));
    await tester.tap(find.byKey(const Key('save-tryon')));
    await tester.pumpAndSettle();
    expect(store.looks.single['occasion'], 'Akşam yemeği');
    expect(store.looks.single['style'], 'Romantik');
    expect(store.looks.single['aiImage'], startsWith('data:image/'));
    expect(transport.paths.where((p) => p == '/api/tryon'), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
