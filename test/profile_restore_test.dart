import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'crop_test_helpers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  testWidgets(
      'stored account restores server avatar ahead of stale local photo',
      (tester) async {
    final photo =
        'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 8, height: 8)))}';
    final secure = MemorySecure();
    final transport = FixtureTransport({
      '/api/account': {
        'user': {'provider': 'google', 'id': 'returning', 'avatar': photo}
      }
    });
    final api = StyleMuseApi(storage: secure, transport: transport);
    secure.values['stylemuse.session.${api.baseUrl.host}'] =
        '__Host-stylemuse_session=existing';
    final store = ClosetStore(memory: true);
    await store.updateProfile({
      'google:returning:photo': 'data:image/png;base64,YQ==',
      'google:other:photo': 'data:image/png;base64,Yg=='
    });
    await tester.pumpWidget(StyleMuseApp(store: store, api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find
        .descendant(
            of: find.byKey(const Key('profile-identity')),
            matching: find.byType(Image))
        .first);
    expect((image.image as MemoryImage).bytes,
        base64Decode(photo.split(',').last));
    expect(transport.paths, ['/api/account', '/api/account']);
  });
  for (final admin in [false, true]) {
    testWidgets(
        'stored account restores ${admin ? 'admin' : 'normal'} menu without paid calls',
        (tester) async {
      final secure = MemorySecure();
      final transport = FixtureTransport({
        '/api/account': {
          'user': {'email': 'restored@example.test', 'admin': admin},
          'balance': 42
        },
        '/api/admin/overview': {'jobs': [], 'operations': []},
        '/api/auth/logout': {},
      });
      final api = StyleMuseApi(storage: secure, transport: transport);
      secure.values['stylemuse.session.${api.baseUrl.host}'] =
          '__Host-stylemuse_session=existing';
      await tester
          .pumpWidget(StyleMuseApp(store: ClosetStore(memory: true), api: api));
      await tester.pumpAndSettle();
      expect(transport.paths, ['/api/account']);
      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
      expect(find.text('restored@example.test'), findsOneWidget);
      expect(find.text('42 Stil Jetonu ›'), findsOneWidget);
      expect(find.text('Çıkış yap'), findsOneWidget);
      final menu = find.text('Yönetici ayarları ve bildirimler');
      expect(menu, admin ? findsOneWidget : findsNothing);
      if (admin) {
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(transport.paths,
            ['/api/account', '/api/account', '/api/admin/overview']);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Çıkış yap'));
      await tester.pumpAndSettle();
      expect(find.text('Google ile giriş yap'), findsOneWidget);
      expect(menu, findsNothing);
      expect(secure.values['stylemuse.session.${api.baseUrl.host}'], isNull);
      expect(transport.paths, [
        '/api/account',
        '/api/account',
        if (admin) '/api/admin/overview',
        '/api/auth/logout'
      ]);
    });
  }

  testWidgets('avatar edits persist only on save and survive portable restore',
      (tester) async {
    final bytes =
        Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 8)));
    final store = ClosetStore(memory: true);
    await store.updateProfile({'name': 'Ada', 'height': '172'});
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture', 'name': 'Ada'}
      },
      '/api/account/avatar': {
        'user': {
          'provider': 'google',
          'id': 'fixture',
          'avatar': 'data:image/png;base64,${base64Encode(bytes)}'
        }
      }
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        pickPhoto: (_) async => bytes,
        api: StyleMuseApi(storage: MemorySecure(), transport: transport)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-refresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bilgilerim'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-height')), findsNothing);
    await tester.tap(find.text('Profil fotoğrafını değiştir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('crop-confirm')), 300);
    await tester.tap(find.byKey(const Key('crop-confirm')));
    await waitForCropReturn(tester, find.byKey(const Key('save-profile')));
    expect(store.profile['photo'], isNull);
    final preview =
        tester.widget<Image>(find.byType(Image).first).image as MemoryImage;
    final avatar = 'data:image/jpeg;base64,${base64Encode(preview.bytes)}';
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();
    expect(transport.bodies['/api/account/avatar']!.single['image'], avatar);
    expect(store.profile['google:fixture:photo'],
        'data:image/png;base64,${base64Encode(bytes)}');
    expect(store.profile['photo'], isNull);
    expect(store.profile['height'], '172');
    final restored = ClosetStore(memory: true);
    await restored.restore(jsonEncode(store.snapshot()));
    expect(restored.profile, store.profile);
    final identityImage = tester.widget<Image>(find
        .descendant(
            of: find.byKey(const Key('profile-identity')),
            matching: find.byType(Image))
        .first);
    expect(identityImage.image, isA<MemoryImage>());
    expect(transport.paths,
        ['/api/session', '/api/account', '/api/account/avatar']);
  });

  testWidgets('token selection cannot enable purchase or submit any API call',
      (tester) async {
    final transport = FixtureTransport({});
    await tester.pumpWidget(StyleMuseApp(
        store: ClosetStore(memory: true),
        api: StyleMuseApi(storage: MemorySecure(), transport: transport)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('token-packs')));
    await tester.pumpAndSettle();
    expect(find.textContaining('USD'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('purchase-disabled')))
            .onPressed,
        isNull);
    expect(transport.paths, isEmpty);
  });
}
