import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'crop_test_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  test('new saved looks require rendered image and complete selection',
      () async {
    final store = ClosetStore(memory: true);
    await store.addGarment(
        image: 'data:image/png;base64,YQ==', category: 'Elbise');
    await expectLater(
        store.saveLook([store.items.single.id]), throwsFormatException);
    expect(store.looks, isEmpty);
  });
  testWidgets('verified administrator opens full native overview via profile',
      (tester) async {
    final secure = MemorySecure();
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/admin/overview': {'jobs': [], 'operations': []}
    });
    await tester.pumpWidget(StyleMuseApp(
        store: ClosetStore(memory: true),
        api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pumpAndSettle();
    final dynamic shell = tester.state(find.byType(StyleMuseShell));
    shell.account = {
      'user': {'id': 'admin', 'admin': true}
    };
    shell.go(4);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Yönetici ayarları ve bildirimler'), 250);
    await tester.tap(find.text('Yönetici ayarları ve bildirimler'));
    await tester.pumpAndSettle();
    expect(transport.paths, contains('/api/admin/overview'));
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('profile card avatar opens native camera gallery chooser',
      (tester) async {
    final secure = MemorySecure();
    final normalized =
        'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 80, height: 120)))}';
    final transport = FixtureTransport({
      '/api/account/avatar': {
        'user': {'id': 'alice', 'provider': 'google', 'avatar': normalized}
      }
    });
    final api = StyleMuseApi(storage: secure, transport: transport);
    final store = ClosetStore(memory: true);
    await store
        .updateProfile({'google:bob:photo': 'data:image/png;base64,Yg=='});
    final bytes =
        Uint8List.fromList(img.encodePng(img.Image(width: 80, height: 120)));
    await tester.pumpWidget(
        StyleMuseApp(store: store, api: api, pickPhoto: (_) async => bytes));
    await tester.pumpAndSettle();
    secure.values['stylemuse.session.${api.baseUrl.host}'] =
        '__Host-stylemuse_session=fixture';
    final dynamic shell = tester.state(find.byType(StyleMuseShell));
    shell.account = {
      'user': {'id': 'alice', 'provider': 'google'}
    };
    shell.go(4);
    await tester.pumpAndSettle();
    await tester.tap(find
        .descendant(
            of: find.byKey(const Key('profile-identity')),
            matching: find.byType(Image))
        .first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    expect(store.profile['google:alice:photo'], isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('crop-confirm')), 250);
    await tester.tap(find.byKey(const Key('crop-confirm')));
    await waitForCropReturn(
        tester, find.byKey(const Key('edit-profile-avatar')));
    final saved = store.profile['google:alice:photo']!;
    final submitted =
        transport.bodies['/api/account/avatar']!.single['image'] as String;
    expect(img.decodeJpg(base64Decode(submitted.split(',').last))!.width, 80);
    expect(saved, normalized);
    expect(transport.paths, ['/api/account', '/api/account/avatar']);
    expect(shell.account['user']['avatar'], normalized);
    expect(store.profile['google:bob:photo'], 'data:image/png;base64,Yg==');
    expect(store.profile['photo'], isNull);
  });
  testWidgets(
      'signed-in token menu uses authenticated Play config and fails closed',
      (tester) async {
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/billing/play/config': {'error': 'play_not_configured'}
    });
    await tester.pumpWidget(StyleMuseApp(
        store: ClosetStore(memory: true),
        api: StyleMuseApi(storage: MemorySecure(), transport: transport)));
    await tester.pumpAndSettle();
    final dynamic shell = tester.state(find.byType(StyleMuseShell));
    shell.account = {
      'user': {'id': 'alice', 'provider': 'google'}
    };
    shell.go(4);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stil Jetonu Al').first);
    await tester.pumpAndSettle();
    expect(transport.paths, ['/api/session', '/api/billing/play/config']);
    expect(find.textContaining('USD'), findsNothing);
    expect(
        tester
            .widget<ButtonStyleButton>(
                find.byKey(const Key('purchase-disabled')))
            .onPressed,
        isNull);
    expect(transport.paths.where((p) => p.endsWith('/verify')), isEmpty);
  });
  testWidgets('outfit ideas stay inline and never save selection as collage',
      (tester) async {
    final store = ClosetStore(memory: true);
    await store.addGarment(
        image: 'data:image/png;base64,YQ==', category: 'Elbise');
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(
            storage: MemorySecure(), transport: FixtureTransport({}))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kombinler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bana fikir ver'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outfit-recommendations')), findsOneWidget);
    expect(find.byKey(const Key('outfits-page')), findsOneWidget);
    expect(store.looks, isEmpty);
  });
}
