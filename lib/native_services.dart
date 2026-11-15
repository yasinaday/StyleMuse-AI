import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'stylemuse_api.dart';

class NativeSecureStore implements SecureStore {
  const NativeSecureStore();
  static const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

Future<Map<String, dynamic>?> googleAccountSignIn(StyleMuseApi api) async {
  final account = await api.account();
  final clientId = account['google_client_id'];
  if (clientId is! String || clientId.isEmpty)
    throw const StyleMuseApiException('google_sign_in_not_configured');
  final google = GoogleSignIn(scopes: ['email'], serverClientId: clientId);
  String? idToken;
  try {
    final user = await google.signIn();
    if (user == null) return null;
    final authentication = await user.authentication;
    idToken = authentication.idToken;
  } on PlatformException catch (error) {
    // Inspect locally, but never propagate raw provider messages or account data.
    if (error.code == 'sign_in_canceled') return null;
    final developerError =
        RegExp(r'ApiException:\s*10\b').hasMatch(error.message ?? '');
    throw StyleMuseApiException(developerError
        ? 'google_oauth_configuration_error'
        : error.code == 'network_error'
            ? 'google_network_error'
            : 'google_sign_in_failed');
  }
  if (idToken == null)
    throw const StyleMuseApiException('google_id_token_unavailable');
  await api.signInGoogle(idToken);
  return api.account();
}
