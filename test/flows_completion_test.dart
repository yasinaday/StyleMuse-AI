import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/mannequin_page.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  test('V1 restore preserves looks when absent and portable style preference',
      () async {
    const photo = 'data:image/png;base64,aGVsbG8=';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: photo, category: 'Elbise');
    await store.saveLook([store.items.single.id]);
    await store.restore(jsonEncode({
      'version': 1,
      'sm-items': jsonEncode([photo]),
      'sm-language': 'de',
      'sm-name': 'Ada',
      'sm-profile-photo': photo,
      'sm-style': 'Minimal',
      'sm-style-profile': '{"height":"172"}',
    }));
    expect(store.items.single.category, 'Diğer');
    expect(store.looks, hasLength(1));
    expect(store.profile['height'], '172');
    expect(store.profile['photo'], photo);
    expect(store.snapshot()['preferences']['sm-style'], 'Minimal');
    final again = ClosetStore(memory: true);
    await again.restore(jsonEncode(store.snapshot()));
    expect(again.snapshot(), store.snapshot());
  });
  test(
      'Android restore and delete survive disk reload and failed restore rolls back',
      () async {
    const photo = 'data:image/png;base64,aGVsbG8=';
    final directory = await Directory.systemTemp.createTemp('stylemuse-flows-');
    addTearDown(() => directory.delete(recursive: true));
    final source = ClosetStore(memory: true);
    await source.updateProfile({
      'google:fixture:name': 'Ada',
      'google:fixture:photo': photo,
      'height': '172'
    }, language: 'de');
    await source.addGarment(image: photo, category: 'Elbise');
    await source.saveLook([source.items.single.id]);
    await source.saveReview({
      'items': [
        {'id': 'x', 'preview': photo, 'category': 'dress'}
      ]
    });
    await source.saveTryOn(photo);
    final store = ClosetStore(directory: directory);
    await store.restore(jsonEncode(source.snapshot()));
    final reloaded = ClosetStore(directory: directory);
    await reloaded.load();
    expect(reloaded.snapshot(), source.snapshot());
    await reloaded.deleteLook(0);
    final deleted = ClosetStore(directory: directory);
    await deleted.load();
    expect(deleted.looks, isEmpty);
    expect(deleted.items, hasLength(1));
    final blocker = File('${directory.path}/not-a-directory');
    await blocker.writeAsString('block');
    final failed = ClosetStore(directory: Directory(blocker.path));
    final before = jsonEncode(failed.snapshot());
    await expectLater(failed.restore(jsonEncode(source.snapshot())),
        throwsA(isA<FileSystemException>()));
    expect(jsonEncode(failed.snapshot()), before);
  });

  test('saved outfit deletion is durable and leaves wardrobe untouched',
      () async {
    const photo = 'data:image/png;base64,aGVsbG8=';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: photo, category: 'Elbise');
    await store.saveLook([store.items.single.id]);
    await store.deleteLook(0);
    expect(store.looks, isEmpty);
    expect(store.items, hasLength(1));
  });
  test('invalid restored Android draft cannot replace existing data', () async {
    const photo = 'data:image/png;base64,aGVsbG8=';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: photo, category: 'Elbise');
    final before = jsonEncode(store.snapshot());
    for (final extra in [
      {'tryonResult': 'https://attacker.invalid/photo'},
      {
        'review': {
          'items': [
            {'id': 'x', 'category': 'Elbise', 'image': 'file:///private'}
          ]
        }
      },
      {
        'review': {'items': 'not a list'}
      },
    ]) {
      await expectLater(
          store.restore(jsonEncode({
            'version': 2,
            'items': [],
            'looks': [],
            'preferences': {},
            ...extra,
          })),
          throwsFormatException);
      expect(jsonEncode(store.snapshot()), before);
    }
  });

  test(
      'Android portable restore replaces review and tryon with backed up state',
      () async {
    const photo = 'data:image/png;base64,aGVsbG8=';
    final source = ClosetStore(memory: true);
    await source.updateProfile(
        {'name': 'Ada', 'photo': photo, 'modelPhoto': photo},
        language: 'en');
    await source.saveReview({
      'job_id': 'backup-job',
      'sourceImage': photo,
      'items': [
        {'id': 'p', 'category': 'Elbise', 'preview': photo}
      ]
    });
    await source.saveTryOn(photo);
    final restored = ClosetStore(memory: true);
    await restored.restore(jsonEncode(source.snapshot()));
    expect(restored.review, source.review);
    expect(restored.tryonResult, photo);
    expect(restored.profile, source.profile);
    expect(restored.language, 'en');
    await restored.restore(jsonEncode(
        {'version': 2, 'items': [], 'looks': [], 'preferences': {}}));
    expect(restored.review, isNull);
    expect(restored.tryonResult, isNull);
  });

  testWidgets(
      'suggestion prefers a dress over an incomplete top and varies alternatives',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photo =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: photo, category: 'Üst giyim');
    await store.addGarment(image: photo, category: 'Elbise');
    await store.addGarment(image: photo, category: 'Elbise');
    final secure = MemorySecure();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MannequinPage(
      store: store,
      workflow: TokenWorkflowController(
          api: StyleMuseApi(storage: secure, transport: FixtureTransport({})),
          storage: secure),
      confirmTokens: (_) async => false,
      pickPhoto: () async => null,
      onBusy: (_) {},
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mannequin-suggest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-tryon')));
    await tester.pumpAndSettle();
    expect(store.looks.single['itemIds'], [store.items[1].id]);
    await tester.tap(find.byKey(const Key('mannequin-suggest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-tryon')));
    await tester.pumpAndSettle();
    expect(store.looks.last['itemIds'], [store.items[2].id]);
  });

  testWidgets('suggested outfit layers outerwear before bags like web tryon',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final photo =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
    final store = ClosetStore(memory: true);
    for (final category in ['Çanta', 'Dış giyim', 'Alt giyim', 'Üst giyim']) {
      await store.addGarment(image: photo, category: category);
    }
    final secure = MemorySecure();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MannequinPage(
      store: store,
      workflow: TokenWorkflowController(
          api: StyleMuseApi(storage: secure, transport: FixtureTransport({})),
          storage: secure),
      confirmTokens: (_) async => false,
      pickPhoto: () async => null,
      onBusy: (_) {},
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mannequin-suggest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-tryon')));
    await tester.pumpAndSettle();
    expect(store.looks.single['itemIds'],
        [for (final item in store.items.reversed) item.id]);
  });

  for (final finish in [true, false])
    testWidgets(
        'sequential category tryon respects separate consent (finish: $finish)',
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
          'style_tokens': 1,
          'estimated_cost_usd': 0.01
        },
        '/api/tryon': {'state': 'done', 'job_id': 'job', 'image': photo},
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
          return finish || confirmations.length == 1;
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
      expect(confirmations, [1, 1]);
      expect(transport.paths.where((p) => p == '/api/tryon'),
          hasLength(finish ? 2 : 1));
      final calls = transport.bodies['/api/tryon']!;
      if (finish) {
        expect(calls[1]['person_image'], store.tryonResult);
        expect(calls[1]['person_image'], isNot(calls[0]['person_image']));
      }
      expect(secure.values.containsKey(TokenWorkflowController.pendingKey),
          isFalse);
      await tester.ensureVisible(find.byKey(const Key('save-tryon')));
      await tester.tap(find.byKey(const Key('save-tryon')));
      await tester.pumpAndSettle();
      expect(store.looks.single['itemIds'],
          store.items.take(finish ? 2 : 1).map((x) => x.id).toList());
      expect(tester.takeException(), isNull);
    });
}
