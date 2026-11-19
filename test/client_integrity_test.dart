import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:stylemuse_ai/photo_crop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/closet.dart';

const original = 'data:image/png;base64,YQ==';
const enhanced = 'data:image/png;base64,Yg==';
const mask = 'data:image/png;base64,Yw==';

void main() {
  for (final size in [(120, 200), (200, 120), (2400, 1800)]) {
    test('crop covers correct source coordinates for $size', () {
      final source = img.Image(width: size.$1, height: size.$2);
      for (final p in source) {
        p.setRgb(p.x * 255 ~/ source.width, p.y * 255 ~/ source.height, 30);
      }
      final bytes = Uint8List.fromList(img.encodePng(source));
      final result =
          img.decodeJpg(cropPhoto(bytes, zoom: 2, panX: .2, panY: -.1))!;
      final side = (size.$1 < size.$2 ? size.$1 : size.$2) / 2;
      final x = ((size.$1 - side) / 2 - .2 * side).round();
      final y = ((size.$2 - side) / 2 + .1 * side).round();
      expect(result.width, side.round());
      final center = result.getPixel(result.width ~/ 2, result.height ~/ 2);
      expect(center.r.toInt(), closeTo((x + side / 2) * 255 / size.$1, 4));
      expect(center.g.toInt(), closeTo((y + side / 2) * 255 / size.$2, 4));
    });
  }
  test('EXIF orientation is baked before crop and large output is bounded', () {
    final source = img.Image(width: 60, height: 100);
    for (final p in source) {
      p.setRgb(p.y < 50 ? 240 : 20, 20, p.y < 50 ? 20 : 240);
    }
    source.exif.imageIfd.orientation = 6;
    final jpeg = Uint8List.fromList(img.encodeJpg(source));
    final output = img.decodeJpg(cropPhoto(jpeg))!;
    expect(output.width, 60);
    expect(output.getPixel(5, 30).b, greaterThan(200));
    expect(output.getPixel(55, 30).r, greaterThan(200));
    final large =
        Uint8List.fromList(img.encodePng(img.Image(width: 2400, height: 1800)));
    expect(img.decodeJpg(cropPhoto(large))!.width, 1600);
  });
  test('cropped profile photos stay per account across disk reload and backup',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('stylemuse-client-profile-');
    addTearDown(() => dir.delete(recursive: true));
    final bytes = cropPhoto(
        Uint8List.fromList(img.encodePng(img.Image(width: 80, height: 120))));
    final photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    final store = ClosetStore(directory: dir);
    await store.updateProfile(
        {'google:alice:photo': photo, 'google:alice:name': 'Alice'});
    await store.updateProfile(
        {'google:bob:photo': enhanced, 'google:bob:name': 'Bob'});
    final reloaded = ClosetStore(directory: dir);
    await reloaded.load();
    expect(reloaded.profile['google:alice:photo'], photo);
    expect(reloaded.profile['google:bob:photo'], enhanced);
    expect(reloaded.profile['photo'], isNull);
    final restored = ClosetStore(memory: true);
    await restored.restore(jsonEncode(reloaded.snapshot()));
    expect(restored.profile['google:alice:photo'], photo);
    expect(restored.profile['google:bob:name'], 'Bob');
  });
  test('backup rejects malformed per-item enhancement metadata', () {
    final store = ClosetStore(memory: true);
    for (final bad in [
      {'mask': 'https://untrusted.invalid/mask'},
      {'originalImage': 42},
      {'sourceItemId': <String>[]},
      {'sourceJobId': ''},
    ]) {
      final data = store.snapshot();
      data['items'] = [
        {'id': 'a', 'image': original, 'category': 'Üst giyim', ...bad}
      ];
      expect(() => normalizeBackup(data), throwsFormatException);
    }
  });
  test('review backup and acceptance reject unsafe originals and masks',
      () async {
    final store = ClosetStore(memory: true);
    for (final field in ['mask', 'originalImage']) {
      final part = {
        'id': 'a',
        'image': original,
        'category': 'Üst giyim',
        field: 'unsafe'
      };
      final data = store.snapshot();
      data['review'] = {
        'items': [part]
      };
      expect(() => normalizeBackup(data), throwsFormatException);
      await expectLater(store.acceptReview([part]), throwsFormatException);
      expect(store.items, isEmpty);
    }
  });
  test('invalid enhancement response leaves draft unchanged', () async {
    final store = ClosetStore(memory: true);
    await store.saveReview({
      'items': [
        {'id': 'a', 'image': original, 'category': 'Üst giyim'},
        {'id': 'b', 'image': mask, 'category': 'Alt giyim'},
      ]
    });
    final before = jsonEncode(store.review);
    for (final updates in [
      <Map<String, dynamic>>[],
      [
        {'id': 'b', 'image': enhanced}
      ],
      [
        {'id': 'a', 'image': enhanced},
        {'id': 'a', 'image': enhanced}
      ],
      [
        {'id': 'a', 'image': 'https://untrusted.invalid/a.png'}
      ],
    ]) {
      await expectLater(
          store.applyReviewEnhancement({'items': updates}, itemIds: ['a']),
          throwsFormatException);
      expect(jsonEncode(store.review), before);
    }
  });
  test(
      'enhancement merges by requested id without replacing original mask or category',
      () async {
    final store = ClosetStore(memory: true);
    await store.saveReview({
      'job_id': 'j',
      'items': [
        {'id': 'a', 'image': original, 'mask': mask, 'category': 'Üst giyim'},
        {'id': 'b', 'image': mask, 'category': 'Alt giyim'},
      ]
    });
    await store.applyReviewEnhancement({
      'items': [
        {'id': 'a', 'image': enhanced, 'mask': original, 'category': 'Elbise'}
      ]
    }, itemIds: <String>[
      'a'
    ]);
    final parts = store.review!['items'] as List;
    expect(parts.first['image'], enhanced);
    expect(parts.first['originalImage'], original);
    expect(parts.first['mask'], mask);
    expect(parts.first['category'], 'Üst giyim');
    expect(parts.last['image'], mask);
    await store.revertReviewEnhancement('a');
    expect((store.review!['items'] as List).first['image'], original);
    expect((store.review!['items'] as List).first['enhanced'], false);
  });
  test(
      'enhanced review survives disk and backup and repeated improvements keep first original',
      () async {
    final dir = await Directory.systemTemp.createTemp('stylemuse-enhancement-');
    addTearDown(() => dir.delete(recursive: true));
    final store = ClosetStore(directory: dir);
    await store.saveReview({
      'job_id': 'j1',
      'items': [
        {'id': 'a', 'image': original, 'mask': mask, 'category': 'Üst giyim'}
      ]
    });
    await store.applyReviewEnhancement({
      'items': [
        {'id': 'a', 'image': enhanced}
      ]
    }, itemIds: [
      'a'
    ]);
    await store.applyReviewEnhancement({
      'items': [
        {'id': 'a', 'image': mask}
      ]
    }, itemIds: [
      'a'
    ]);
    final loaded = ClosetStore(directory: dir);
    await loaded.load();
    final restored = ClosetStore(memory: true);
    await restored.restore(jsonEncode(loaded.snapshot()));
    await restored.revertReviewEnhancement('a');
    final parts =
        (restored.review!['items'] as List).cast<Map<String, dynamic>>();
    await restored.acceptReview(parts.toList());
    expect(restored.items.single.originalImage, original);
    expect(restored.items.single.image, original);
    expect(restored.items.single.mask, mask);
    expect(restored.items.single.sourceItemId, 'a');
    expect(restored.items.single.sourceJobId, 'j1');
  });
  test('storage failure rolls enhancement back without mutating original draft',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('stylemuse-enhancement-fail-');
    addTearDown(() => dir.delete(recursive: true));
    final store = ClosetStore(directory: dir);
    await store.saveReview({
      'items': [
        {'id': 'a', 'image': original}
      ]
    });
    final before = jsonEncode(store.review);
    final blocked = File('${dir.path}/block');
    await blocked.writeAsString('block');
    store.directory = Directory(blocked.path);
    await expectLater(
        store.applyReviewEnhancement({
          'items': [
            {'id': 'a', 'image': enhanced}
          ]
        }, itemIds: [
          'a'
        ]),
        throwsA(isA<FileSystemException>()));
    expect(jsonEncode(store.review), before);
  });
  test('accepting then editing a review preserves per-item provenance',
      () async {
    final store = ClosetStore(memory: true);
    await store.saveReview({'job_id': 'j1', 'items': []});
    await store.acceptReview([
      {
        'id': 'p1',
        'image': enhanced,
        'category': 'Üst giyim',
        'originalImage': original,
        'mask': mask,
      }
    ]);
    await store.editGarment(store.items.single.id, category: 'Dış giyim');
    final saved = store.items.single.toJson();
    expect(saved['sourceItemId'], 'p1');
    expect(saved['sourceJobId'], 'j1');
    expect(saved['originalImage'], original);
    expect(saved['mask'], mask);
    expect(saved['category'], 'Dış giyim');
  });
  test('garment roundtrip retains extraction identity mask and original', () {
    final raw = <String, dynamic>{
      'id': 'local',
      'image': enhanced,
      'category': 'Üst giyim',
      'sourceItemId': 'p1',
      'sourceJobId': 'j1',
      'originalImage': original,
      'mask': mask,
    };
    expect(ClosetItem.fromJson(raw).toJson(), raw);
  });
}
