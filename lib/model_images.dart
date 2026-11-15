import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'closet.dart';

String mannequinAsset(Map<String, String> profile) {
  final tone = ['light', 'medium', 'deep'].contains(profile['tone'])
      ? profile['tone']
      : 'medium';
  final shape = ['straight', 'curved', 'pear', 'oval', 'triangle']
          .contains(profile['shape'])
      ? profile['shape']
      : 'straight';
  final height = double.tryParse(profile['height'] ?? '') ?? 170;
  final weight = double.tryParse(profile['weight'] ?? '') ?? 65;
  final full = ['XL', 'XXL', '3XL', '4XL'].contains(profile['size']) ||
      weight / ((height / 100) * (height / 100)) >= 27;
  return 'assets/mannequins/profile-$tone-$shape-${full ? 'full' : 'standard'}.webp';
}

Future<String> jpegData(String image) async {
  final Uint8List bytes;
  if (image.startsWith('data:')) {
    bytes = base64Decode(image.split(',').last);
  } else {
    final data = await rootBundle.load(image);
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
  var decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Invalid image');
  decoded = img.bakeOrientation(decoded);
  if (decoded.width > 1400 || decoded.height > 1800)
    decoded = img.copyResize(decoded,
        width: decoded.width >= decoded.height ? 1400 : null,
        height: decoded.height > decoded.width ? 1800 : null);
  return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(decoded, quality: 90))}';
}

/// No session headers, redirects, arbitrary hosts, or unbounded downloads.
Future<String> loadTryOnImage(Object? value) async {
  if (value is String && safeImage(value)) return jpegData(value);
  if (value is! String) throw const FormatException('Missing result image');
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      !{'fal.media', 'v3.fal.media', 'v3b.fal.media'}.contains(uri.host))
    throw const FormatException('Untrusted image URL');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 || response.contentLength > 20 * 1024 * 1024)
      throw const FormatException('Invalid image response');
    final builder = BytesBuilder();
    await for (final bytes in response.timeout(const Duration(seconds: 30))) {
      builder.add(bytes);
      if (builder.length > 20 * 1024 * 1024)
        throw const FormatException('Image too large');
    }
    return await jpegData(
        'data:image/jpeg;base64,${base64Encode(builder.takeBytes())}');
  } finally {
    client.close(force: true);
  }
}
