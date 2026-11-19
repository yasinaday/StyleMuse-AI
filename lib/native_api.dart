import 'dart:convert';
import 'stylemuse_api.dart';

/// Account photo requests reuse the session/Origin/timeout protections of the API.
/// No inference, retries, or anonymous-session bootstrap is performed here.
class NativeAvatarApi {
  NativeAvatarApi(this.api);
  final StyleMuseApi api;

  static bool validPhoto(Object? value) {
    if (value is! String || value.length > 8 * 1024 * 1024) return false;
    final match =
        RegExp(r'^data:image/(jpeg|png);base64,([A-Za-z0-9+/]+={0,2})$')
            .firstMatch(value);
    if (match == null) return false;
    try {
      return base64Decode(match.group(2)!).isNotEmpty;
    } on FormatException {
      return false;
    }
  }

  static String? restoredPhoto(Map<String, dynamic> account,
      {required String ownerId}) {
    final user = account['user'];
    if (user is! Map || user['provider'] != 'google' || user['id'] != ownerId)
      return null;
    final avatar = user['avatar'];
    return validPhoto(avatar) ? avatar as String : null;
  }

  Future<String> upload(String image, {required String ownerId}) async {
    if (ownerId.isEmpty || !validPhoto(image)) {
      throw const StyleMuseApiException('invalid_avatar');
    }
    // restoreAccount, unlike post(), cannot create an anonymous session.
    final saved =
        await api.storage.read('stylemuse.session.${api.baseUrl.host}');
    if (saved == null || saved.isEmpty) {
      throw const StyleMuseApiException('sign_in_required');
    }
    final result = await api.post('/api/account/avatar', {'image': image});
    final avatar = restoredPhoto(result, ownerId: ownerId);
    if (avatar == null)
      throw const StyleMuseApiException('invalid_avatar_response');
    return avatar;
  }
}
