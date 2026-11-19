import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'package:flutter/services.dart';
import 'ui_api_test.dart' show MemorySecure;
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/native_services.dart';
import 'package:material_ui/material_ui.dart';

class AccountTransport implements ApiTransport {
  final paths = <String>[];
  final delayed = Completer<ApiResponse>();
  bool failLogout = false;
  bool unauthorized = false;
  @override
  Future<ApiResponse> post(
      Uri url, Map<String, String> headers, Map<String, dynamic> body) async {
    paths.add(url.path);
    if (unauthorized)
      return const ApiResponse(401, {'error': 'session_expired'});
    if (url.path == '/api/session')
      return const ApiResponse(200, {},
          sessionCookie: '__Host-stylemuse_session=anonymous');
    if (url.path == '/api/auth/logout') {
      return ApiResponse(failLogout ? 503 : 200, {});
    }
    return delayed.future;
  }
}

class ChooserApi extends StyleMuseApi {
  ChooserApi() : super(storage: MemorySecure());
  String? submitted;
  @override
  Future<Map<String, dynamic>> account() async => {
        'google_client_id': 'offline-fixture.apps.googleusercontent.com',
        if (submitted != null) 'user': {'id': 'fixture', 'name': 'Fixture'},
      };
  @override
  Future<Map<String, dynamic>> signInGoogle(String idToken) async {
    submitted = idToken;
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native chooser signs out first and forwards provider token to backend',
      () async {
    final methods = <String>[];
    const channel = MethodChannel('plugins.flutter.io/google_sign_in');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'signIn')
        return {
          'email': 'fixture@example.test',
          'id': 'fixture',
          'displayName': 'Fixture',
        };
      if (call.method == 'getTokens')
        return {'idToken': 'offline-provider-fixture'};
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final api = ChooserApi();
    final account = await googleAccountSignIn(api);
    expect(methods.indexOf('signOut'), lessThan(methods.indexOf('signIn')));
    expect(methods, isNot(contains('signInSilently')));
    expect(api.submitted, 'offline-provider-fixture');
    expect((account!['user'] as Map)['id'], 'fixture');
  });

  testWidgets('profile exposes nine flags and server token balance',
      (tester) async {
    final secure = MemorySecure();
    final transport = AccountTransport();
    transport.delayed.complete(const ApiResponse(200, {
      'user': {'id': 'fixture', 'name': 'Google Name'},
      'balance': 73,
    }));
    final api = StyleMuseApi(storage: secure, transport: transport);
    secure.values['stylemuse.session.${api.baseUrl.host}'] =
        '__Host-stylemuse_session=existing';
    final store = ClosetStore(memory: true);
    await store.updateProfile({
      'google:fixture:name': 'Saved Name',
      'google:other:name': 'Other Name'
    });
    await tester.pumpWidget(StyleMuseApp(store: store, api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Saved Name'), findsOneWidget);
    expect(find.text('Other Name'), findsNothing);
    expect(find.text('73 Stil Jetonu ›'), findsOneWidget);
    final dropdown = tester
        .widget<DropdownButton<String>>(find.byKey(const Key('app-language')));
    expect(dropdown.items!.map((e) => e.value).toList(),
        ['tr', 'en', 'de', 'ru', 'ar', 'fr', 'hi', 'zh', 'ja']);
    expect(dropdown.items!.map((e) => (e.child as Text).data).toList(), [
      '🇹🇷 Türkçe',
      '🇬🇧 English',
      '🇩🇪 Deutsch',
      '🇷🇺 Русский',
      '🇸🇦 العربية',
      '🇫🇷 Français',
      '🇮🇳 हिन्दी',
      '🇨🇳 简体中文',
      '🇯🇵 日本語'
    ]);
    expect(transport.paths, ['/api/account']);
  });

  testWidgets('logout closes privileged dialogs before late balance arrives',
      (tester) async {
    const channel = MethodChannel('plugins.flutter.io/google_sign_in');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final secure = MemorySecure();
    final transport = AccountTransport();
    final api = StyleMuseApi(storage: secure, transport: transport);
    await tester
        .pumpWidget(StyleMuseApp(store: ClosetStore(memory: true), api: api));
    await tester.pumpAndSettle();
    secure.values['stylemuse.session.${api.baseUrl.host}'] =
        '__Host-stylemuse_session=old';
    final dynamic state = tester.state(find.byType(StyleMuseShell));
    state.account = {
      'user': {'id': 'old', 'admin': true}
    };
    unawaited(state.openAdminSettings() as Future<void>);
    await tester.pumpAndSettle();
    expect(find.text('Yönetici ayarları ve bildirimler'), findsOneWidget);
    await state.accountAction(logout: true);
    await tester.pumpAndSettle();
    expect(find.text('Yönetici ayarları ve bildirimler'), findsNothing);
    transport.delayed.complete(const ApiResponse(200, {'available_usd': 123}));
    await tester.pumpAndSettle();
    expect(find.text('fal.ai · USD 123.00'), findsNothing);
  });

  test('logout without credentials never creates an anonymous session',
      () async {
    final transport = AccountTransport();
    final api = StyleMuseApi(storage: MemorySecure(), transport: transport);
    await api.logout();
    expect(transport.paths, isEmpty);
  });

  testWidgets('expired account refresh removes stale privileged identity',
      (tester) async {
    final secure = MemorySecure();
    final transport = AccountTransport()..unauthorized = true;
    final api = StyleMuseApi(storage: secure, transport: transport);
    await tester
        .pumpWidget(StyleMuseApp(store: ClosetStore(memory: true), api: api));
    await tester.pumpAndSettle();
    secure.values['stylemuse.session.${api.baseUrl.host}'] =
        '__Host-stylemuse_session=old';
    final dynamic state = tester.state(find.byType(StyleMuseShell));
    state.account = {
      'user': {'id': 'old', 'admin': true},
      'balance': 42
    };
    await state.accountAction();
    await tester.pumpAndSettle();
    expect(state.account, isNull);
  });

  testWidgets(
      'failed remote logout still clears identity and native Google login',
      (tester) async {
    final methods = <String>[];
    const channel = MethodChannel('plugins.flutter.io/google_sign_in');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      methods.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final transport = AccountTransport()..failLogout = true;
    final secure = MemorySecure();
    final api = StyleMuseApi(storage: secure, transport: transport);
    await tester
        .pumpWidget(StyleMuseApp(store: ClosetStore(memory: true), api: api));
    await tester.pumpAndSettle();
    secure.values['stylemuse.session.${api.baseUrl.host}'] =
        '__Host-stylemuse_session=old';
    final dynamic state = tester.state(find.byType(StyleMuseShell));
    state.account = {
      'user': {'id': 'old', 'admin': true},
      'balance': 12
    };
    await state.accountAction(logout: true);
    await tester.pumpAndSettle();
    expect(state.account, isNull);
    expect(methods, contains('signOut'));
  });

  test('late account response cannot restore a logged out session', () async {
    final store = MemorySecure();
    final transport = AccountTransport();
    final api = StyleMuseApi(storage: store, transport: transport);
    final key = 'stylemuse.session.${api.baseUrl.host}';
    store.values[key] = '__Host-stylemuse_session=old';
    final pending = api.account();
    final rejected = expectLater(
        pending,
        throwsA(isA<StyleMuseApiException>()
            .having((e) => e.code, 'code', 'session_changed')));
    await Future<void>.delayed(Duration.zero);
    await api.logout();
    transport.delayed.complete(const ApiResponse(200, {'balance': 99},
        sessionCookie: '__Host-stylemuse_session=stale'));
    await rejected;
    expect(store.values[key], isNull);
  });

  testWidgets('normal account cannot call administrator handler directly',
      (tester) async {
    final transport = AccountTransport();
    await tester.pumpWidget(StyleMuseApp(
        store: ClosetStore(memory: true),
        api: StyleMuseApi(storage: MemorySecure(), transport: transport)));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(StyleMuseShell));
    unawaited(state.openAdminSettings() as Future<void>);
    await tester.pump();
    expect(transport.paths, isEmpty);
    expect(find.text('Yönetici ayarları ve bildirimler'), findsNothing);
  });

  test('offline logout clears credentials even when revocation fails',
      () async {
    final store = MemorySecure();
    final transport = AccountTransport()..failLogout = true;
    final api = StyleMuseApi(storage: store, transport: transport);
    final key = 'stylemuse.session.${api.baseUrl.host}';
    store.values[key] = '__Host-stylemuse_session=old';
    await expectLater(api.logout(), throwsA(isA<StyleMuseApiException>()));
    expect(store.values[key], isNull);
    expect(await api.restoreAccount(), isNull);
    expect(transport.paths, ['/api/auth/logout']);
  });
}
