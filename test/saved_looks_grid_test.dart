import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/saved_looks_grid.dart';

void main() {
  testWidgets('legacy collages are preserved but excluded from photo grid',
      (tester) async {
    final store = ClosetStore(memory: true);
    const photo = 'https://fal.media/files/result.jpg';
    await store.restore(jsonEncode({
      ...store.snapshot(),
      'looks': [
        {'images': [], 'occasion': 'Legacy collage'},
        {'images': [], 'aiImage': photo, 'occasion': 'Completed photo'},
      ],
    }));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SavedLooksGrid(store: store))));
    await tester.pumpAndSettle();
    expect(find.text('Legacy collage'), findsNothing);
    expect(find.text('Completed photo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-look-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-look')));
    await tester.pumpAndSettle();
    expect(store.looks.single['occasion'], 'Legacy collage');
    expect(find.text('Henüz kayıtlı kombin yok.'), findsOneWidget);
  });
  testWidgets(
      'restored trusted remote outfit shares its image URL without downloading',
      (tester) async {
    const url = 'https://fal.media/files/fixture.jpg';
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      return 'fixture';
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final store = ClosetStore(memory: true);
    await store.restore(jsonEncode({
      ...store.snapshot(),
      'looks': [
        {'aiImage': url, 'images': [], 'itemIds': []}
      ]
    }));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SavedLooksGrid(store: store))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-look-0')));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'share');
    expect(calls.single.arguments['text'], contains(url));
  });
  testWidgets(
      'two column saved looks share selected look and confirm before delete',
      (tester) async {
    final image =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: image, category: 'Elbise');
    await store
        .saveLook([store.items.single.id], occasion: 'Günlük', aiImage: image);
    await store.saveLook([store.items.single.id],
        occasion: 'Özel davet',
        aiImage:
            'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 21, height: 31)))}');
    final shared = <Map<String, dynamic>>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SavedLooksGrid(
      store: store,
      shareLook: (look) async {
        shared.add(look);
      },
    )))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved-look-0')), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('saved-look-0'))).dy,
        tester.getTopLeft(find.byKey(const Key('saved-look-1'))).dy);
    expect(tester.getTopLeft(find.byKey(const Key('saved-look-0'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const Key('saved-look-1'))).dx));
    await tester.tap(find.byKey(const Key('share-look-0')));
    await tester.pumpAndSettle();
    expect(shared.single['occasion'], 'Özel davet');
    await tester.tap(find.byKey(const Key('delete-look-0')));
    await tester.pumpAndSettle();
    expect(store.looks, hasLength(2));
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(store.looks, hasLength(2));
    await tester.tap(find.byKey(const Key('delete-look-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-look')));
    await tester.pumpAndSettle();
    expect(store.looks.single['occasion'], 'Günlük');
    expect(store.items, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
