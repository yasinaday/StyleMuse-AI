import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/saved_looks_grid.dart';

void main() {
  testWidgets('shell exposes two-column saved looks with share and delete',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ClosetStore(memory: true);
    final image =
        'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 20, height: 30)))}';
    await store.addGarment(image: image, category: 'Elbise');
    await store.saveLook([store.items.single.id], occasion: 'Günlük');
    await store.saveLook([store.items.single.id], occasion: 'Özel davet');
    await tester.pumpWidget(StyleMuseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kombinler').last);
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
            of: find.byKey(const Key('outfits-page')),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.byType(SavedLooksGrid), 250,
        scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('share-look-0')), findsOneWidget);
    expect(find.byKey(const Key('delete-look-0')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('saved-look-0'))).dy,
        tester.getTopLeft(find.byKey(const Key('saved-look-1'))).dy);
    await tester.ensureVisible(find.byKey(const Key('delete-look-0')));
    await tester.tap(find.byKey(const Key('delete-look-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-look')));
    await tester.pumpAndSettle();
    expect(store.looks, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
