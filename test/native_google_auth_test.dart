import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/native_services.dart';
import '../lib/stylemuse_api.dart';
import 'stylemuse_api_test.dart' show MemorySecureStore, FakeTransport;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/google_sign_in');
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('Android developer error is diagnosed without exposing plugin details',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'signIn') {
        throw PlatformException(
            code: 'sign_in_failed',
            message:
                'com.google.android.gms.common.api.ApiException: 10: private-account');
      }
      return null;
    });
    final transport = FakeTransport();
    transport.handler = (p, b) async => const ApiResponse(200, {});
    final api = _ConfiguredApi(transport);
    await expectLater(
        googleAccountSignIn(api),
        throwsA(isA<StyleMuseApiException>().having(
            (e) => e.code, 'code', 'google_oauth_configuration_error')));
    expect(transport.calls, isEmpty);
  });
}

class _ConfiguredApi extends StyleMuseApi {
  _ConfiguredApi(FakeTransport transport)
      : super(storage: MemorySecureStore(), transport: transport);
  @override
  Future<Map<String, dynamic>> account() async => {
        'google_client_id': 'fixture.apps.googleusercontent.com',
      };
}
