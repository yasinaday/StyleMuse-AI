import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/closet.dart';

void main() {
  test('completed saves deduplicate concurrent and restarted retries',
      () async {
    final directory = await Directory.systemTemp.createTemp('saved-look-');
    addTearDown(() => directory.delete(recursive: true));
    const photo = 'data:image/png;base64,YQ==';
    final store = ClosetStore(directory: directory);
    await store.addGarment(image: photo, category: 'Üst giyim');
    await store.addGarment(image: photo, category: 'Alt giyim');
    final ids = store.items.map((item) => item.id).toList();
    await Future.wait([
      store.saveLook(ids, aiImage: photo),
      store.saveLook(ids.reversed.toList(), aiImage: photo),
    ]);
    final original = store.looks.single;
    final reopened = ClosetStore(directory: directory);
    await reopened.load();
    await reopened.saveLook(ids, aiImage: photo);
    await reopened.saveLook(ids, aiImage: photo, occasion: 'Seyahat');
    expect(reopened.looks.single, original);
    await reopened.saveLook(ids, aiImage: 'data:image/png;base64,Yg==');
    expect(reopened.looks, hasLength(2));
  });

  test('failed writes roll back and allow the same save to be retried',
      () async {
    final directory = await Directory.systemTemp.createTemp('saved-look-');
    addTearDown(() => directory.delete(recursive: true));
    const photo = 'data:image/png;base64,YQ==';
    final store = ClosetStore(directory: directory);
    await store.addGarment(image: photo, category: 'Elbise');
    final ids = [store.items.single.id];
    final obstacle = await Directory('${directory.path}/closet.tmp').create();
    await expectLater(store.saveLook(ids, aiImage: photo),
        throwsA(isA<FileSystemException>()));
    expect(store.looks, isEmpty);
    await obstacle.delete();
    await store.saveLook(ids, aiImage: photo);
    final reopened = ClosetStore(directory: directory);
    await reopened.load();
    expect(reopened.looks.single['aiImage'], photo);
  });
}
