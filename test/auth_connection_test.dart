import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/stylemuse_api.dart';
import 'stylemuse_api_test.dart' show MemorySecureStore;

class OfflineTransport implements ApiTransport {
  int calls = 0;
  @override
  Future<ApiResponse> post(
      Uri url, Map<String, String> headers, Map<String, dynamic> body) async {
    calls++;
    throw const SocketException('private-host-and-account');
  }
}

void main() {
  test('account connectivity failure gives safe diagnostic without retry',
      () async {
    final transport = OfflineTransport();
    final api =
        StyleMuseApi(storage: MemorySecureStore(), transport: transport);
    await expectLater(
        api.account(),
        throwsA(isA<StyleMuseApiException>()
            .having((e) => e.code, 'code', 'api_network_error')));
    expect(transport.calls, 1);
  });
}
