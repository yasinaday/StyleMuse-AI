import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/native_api.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';

void main() {
  test('new install refuses upload without creating an anonymous session',
      () async {
    final transport = FixtureTransport({});
    final api = StyleMuseApi(storage: MemorySecure(), transport: transport);
    await expectLater(
        NativeAvatarApi(api)
            .upload('data:image/jpeg;base64,/9j/2Q==', ownerId: 'a'),
        throwsA(isA<StyleMuseApiException>()
            .having((e) => e.code, 'code', 'sign_in_required')));
    expect(transport.paths, isEmpty);
  });
  test('restoration is strict per Google account and rejects unsafe photos',
      () {
    const image = 'data:image/jpeg;base64,/9j/2Q==';
    final account = <String, dynamic>{
      'user': {'provider': 'google', 'id': 'a', 'avatar': image}
    };
    expect(NativeAvatarApi.restoredPhoto(account, ownerId: 'a'), image);
    expect(NativeAvatarApi.restoredPhoto(account, ownerId: 'b'), isNull);
    expect(
        NativeAvatarApi.restoredPhoto({
          'user': {
            'provider': 'google',
            'id': 'a',
            'avatar': 'https://evil.test/image'
          }
        }, ownerId: 'a'),
        isNull);
    expect(NativeAvatarApi.validPhoto('data:image/svg+xml;base64,PHN2Zz4='),
        isFalse);
    expect(NativeAvatarApi.validPhoto('data:image/jpeg;base64,A'), isFalse);
  });
  test('wrong-account upload response cannot become local photo', () async {
    final transport = FixtureTransport({
      '/api/account/avatar': {
        'user': {
          'provider': 'google',
          'id': 'b',
          'avatar': 'data:image/jpeg;base64,/9j/2Q=='
        }
      }
    });
    final secure = MemorySecure();
    final api = StyleMuseApi(storage: secure, transport: transport);
    secure.values['stylemuse.session.${api.baseUrl.host}'] =
        '__Host-stylemuse_session=existing';
    await expectLater(
        NativeAvatarApi(api)
            .upload('data:image/jpeg;base64,/9j/2Q==', ownerId: 'a'),
        throwsA(isA<StyleMuseApiException>()));
    expect(transport.paths, ['/api/account/avatar']);
  });
  test('avatar upload uses authenticated account endpoint without paid work',
      () async {
    const image = 'data:image/jpeg;base64,/9j/2Q==';
    final transport = FixtureTransport({
      '/api/account/avatar': {
        'user': {'provider': 'google', 'id': 'a', 'avatar': image}
      },
    });
    final secure = MemorySecure();
    final api = StyleMuseApi(storage: secure, transport: transport);
    secure.values['stylemuse.session.${api.baseUrl.host}'] =
        '__Host-stylemuse_session=existing';
    final result = await NativeAvatarApi(api).upload(image, ownerId: 'a');
    expect(result, image);
    expect(transport.paths, ['/api/account/avatar']);
  });
}

class MemorySecure implements SecureStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FixtureTransport implements ApiTransport {
  FixtureTransport(this.replies);
  final Map<String, Map<String, dynamic>> replies;
  final paths = <String>[];
  @override
  Future<ApiResponse> post(
      Uri url, Map<String, String> headers, Map<String, dynamic> body) async {
    paths.add(url.path);
    expect(headers['Cookie'], '__Host-stylemuse_session=existing');
    expect(body.keys, ['image']);
    return ApiResponse(200, replies[url.path]!);
  }
}
