import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/closet.dart';

void main() {
  test('PR16 wardrobe index and JPEG files migrate without deleting originals',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('stylemuse-migration-');
    addTearDown(() => directory.delete(recursive: true));
    await Directory('${directory.path}/wardrobe').create();
    await File('${directory.path}/wardrobe/items.json')
        .writeAsString('[{"id":"123","category":"Çanta"}]');
    await File('${directory.path}/wardrobe/123.jpg').writeAsBytes([1, 2, 3]);
    final store = ClosetStore(directory: directory);
    await store.load();
    expect(store.items.single.category, 'Çanta');
    expect(store.items.single.image, 'data:image/jpeg;base64,AQID');
    expect(await File('${directory.path}/wardrobe/123.jpg').exists(), isTrue);
    expect(await File('${directory.path}/closet.json').exists(), isTrue);
  });
  test(
      'invalid backups reject atomically and do not allow paths or remote images',
      () async {
    final store = ClosetStore(memory: true);
    await store.addGarment(
        image: 'data:image/png;base64,aGVsbG8=', category: 'Elbise');
    final before = jsonEncode(store.snapshot());
    for (final item in [
      {
        'id': '../escape',
        'category': 'Elbise',
        'image': 'data:image/png;base64,aGVsbG8='
      },
      {
        'id': 'ok',
        'category': 'Other',
        'image': 'data:image/png;base64,aGVsbG8='
      },
      {
        'id': 'ok',
        'category': 'Elbise',
        'image': 'https://attacker.invalid/a.png'
      },
    ]) {
      await expectLater(
          store.restore(jsonEncode({
            'version': 2,
            'items': [item],
            'looks': [],
            'preferences': {}
          })),
          throwsFormatException);
      expect(jsonEncode(store.snapshot()), before);
    }
    await expectLater(
        store.restore(jsonEncode(
            {'version': 999, 'items': [], 'looks': [], 'preferences': {}})),
        throwsFormatException);
  });
  test('restores web v2 backup including saved outfits without losing photos',
      () async {
    final store = ClosetStore(memory: true);
    await store.restore(jsonEncode({
      'version': 2,
      'items': [
        {
          'id': 'a',
          'category': 'Elbise',
          'image': 'data:image/png;base64,aGVsbG8='
        }
      ],
      'looks': [
        {
          'images': ['data:image/png;base64,aGVsbG8='],
          'occasion': 'Daily',
          'itemIds': ['a']
        }
      ],
      'preferences': {
        'sm-name': 'Ada',
        'sm-language': 'en',
        'sm-style-profile': '{"height":"175"}'
      }
    }));
    expect(store.items.single.id, 'a');
    expect(store.profile['name'], 'Ada');
    expect(store.profile['height'], '175');
    expect(store.language, 'en');
    expect((store.snapshot()['looks'] as List).single['occasion'], 'Daily');
  });
  test('portable backup includes outfits photos profile and language',
      () async {
    final store = ClosetStore(memory: true);
    await store.addGarment(
        image: 'data:image/png;base64,aGVsbG8=', category: 'Elbise');
    await store.updateProfile({'name': 'Ada'}, language: 'de');
    expect(store.snapshot()['looks'], isA<List>());
    expect(store.snapshot()['preferences'], isA<Map>());
    expect(store.snapshot()['preferences']['sm-language'], 'de');
  });
  test('wardrobe photos category and profile survive atomic disk reload',
      () async {
    final directory = await Directory.systemTemp.createTemp('stylemuse-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = ClosetStore(directory: directory);
    await store.load();
    await store.addGarment(
        image: 'data:image/png;base64,aGVsbG8=', category: 'Üst giyim');
    await store.updateProfile({'name': 'Ada', 'height': '172'}, language: 'ja');
    final again = ClosetStore(directory: directory);
    await again.load();
    expect(again.items.single.category, 'Üst giyim');
    expect(again.items.single.image, 'data:image/png;base64,aGVsbG8=');
    expect(again.profile['name'], 'Ada');
    expect(again.language, 'ja');
    expect(
        jsonDecode(await File('${directory.path}/closet.json').readAsString())[
            'version'],
        2);
  });
}
