import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Implement with Android Keystore-backed flutter_secure_storage, never prefs.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class ApiResponse {
  const ApiResponse(this.status, this.body, {this.sessionCookie});
  final int status;
  final Map<String, dynamic> body;
  final String? sessionCookie;
}

abstract interface class ApiTransport {
  Future<ApiResponse> post(
      Uri url, Map<String, String> headers, Map<String, dynamic> body);
}

/// No retry of any POST. Redirects never receive cookies or ID tokens.
class IoApiTransport implements ApiTransport {
  IoApiTransport({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;
  @override
  Future<ApiResponse> post(
      Uri url, Map<String, String> headers, Map<String, dynamic> body) async {
    final request = await _client.postUrl(url);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('invalid_server_response');
    }
    String? cookie;
    for (final c in response.cookies) {
      if (c.name == '__Host-stylemuse_session') cookie = '${c.name}=${c.value}';
    }
    return ApiResponse(response.statusCode, decoded, sessionCookie: cookie);
  }

  void close() => _client.close(force: true);
}

class StyleMuseApiException implements Exception {
  const StyleMuseApiException(this.code, {this.status});
  final String code;
  final int? status;
  @override
  String toString() => 'StyleMuseApiException($code)';
}

class StyleMuseApi {
  StyleMuseApi(
      {required this.storage,
      ApiTransport? transport,
      Uri? baseUrl,
      this.origin = 'https://yasinaday.github.io',
      this.timeout = const Duration(seconds: 120)})
      : transport = transport ?? IoApiTransport(),
        baseUrl = baseUrl ??
            Uri.parse('https://stylemuse-api.129.121.148.187.sslip.io') {
    if (this.baseUrl.scheme != 'https' ||
        this.baseUrl.userInfo.isNotEmpty ||
        this.baseUrl.hasQuery ||
        this.baseUrl.hasFragment) {
      throw ArgumentError('HTTPS API origin required');
    }
  }
  final SecureStore storage;
  final ApiTransport transport;
  final Uri baseUrl;
  final String origin;
  final Duration timeout;
  String get _cookieKey => 'stylemuse.session.${baseUrl.host}';
  String? _cookie;
  Future<void>? _initializing;
  Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object e) {
        _initializing = null;
        throw e;
      });
  Future<void> _initialize() async {
    _cookie = await storage.read(_cookieKey);
    if (_cookie == null) await _request('/api/session', {});
  }

  Future<Map<String, dynamic>> _request(
      String path, Map<String, dynamic> body) async {
    final ApiResponse response;
    try {
      response = await transport
          .post(
              baseUrl.resolve(path),
              {
                'Content-Type': 'application/json',
                'Origin': origin,
                if (_cookie != null) 'Cookie': _cookie!,
              },
              body)
          .timeout(timeout);
    } on SocketException {
      throw const StyleMuseApiException('api_network_error');
    } on HandshakeException {
      throw const StyleMuseApiException('api_network_error');
    } on HttpException {
      throw const StyleMuseApiException('api_network_error');
    } on TimeoutException {
      throw const StyleMuseApiException('api_timeout');
    } on FormatException {
      throw const StyleMuseApiException('invalid_server_response');
    }
    if (response.sessionCookie != null) {
      await storage.write(_cookieKey, response.sessionCookie!);
      _cookie = response.sessionCookie;
    }
    if (response.status < 200 || response.status >= 300) {
      if (response.status == 401) {
        _cookie = null;
        _initializing = null;
        await storage.delete(_cookieKey);
      }
      final detail = response.body['error'] ?? response.body['detail'];
      throw StyleMuseApiException(detail is String ? detail : 'server_error',
          status: response.status);
    }
    return response.body;
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    if (!path.startsWith('/api/') ||
        path.contains('..') ||
        path.contains('?') ||
        path.contains('#')) {
      throw ArgumentError('Invalid API path');
    }
    await initialize();
    return _request(path, body);
  }

  Future<Map<String, dynamic>> account() async {
    try {
      return await post('/api/account', {});
    } on StyleMuseApiException catch (error) {
      if (error.status != 401) rethrow;
      return post('/api/account', {});
    }
  }
  Future<Map<String, dynamic>> signInGoogle(String idToken) =>
      post('/api/auth/google/android', {'credential': idToken});
  Future<void> logout() async {
    await post('/api/auth/logout', {});
    await storage.delete(_cookieKey);
    _cookie = null;
    _initializing = null;
  }
}

typedef TokenConfirmation = Future<bool> Function(int tokens);

/// A single durable operation. A done result stays recoverable until acknowledged.
class TokenWorkflowController {
  TokenWorkflowController(
      {required this.api, required this.storage, String Function()? requestId})
      : requestId = requestId ?? _newId;
  final StyleMuseApi api;
  final SecureStore storage;
  final String Function() requestId;
  static String _newId() => base64Url
      .encode(List<int>.generate(24, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  static const pendingKey = 'stylemuse.pending';
  Map<String, dynamic>? _pending;
  Map<String, dynamic>? get pending => _pending == null
      ? null
      : jsonDecode(jsonEncode(_pending)) as Map<String, dynamic>;
  bool _busy = false;
  bool _cancelled = false;

  /// Stops local continuation, not provider work or token charging. Recovery remains.
  void cancel() {
    _cancelled = true;
  }

  Future<String> _owner() async {
    final account = await api.account();
    final user = account['user'];
    if (user is! Map ||
        user['provider'] != 'google' ||
        user['id'] is! String ||
        (user['id'] as String).isEmpty) {
      throw const StyleMuseApiException('sign_in_required');
    }
    return 'google:${user['id']}';
  }

  Future<void> _save() => storage.write(pendingKey, jsonEncode(_pending));

  Future<Map<String, dynamic>?> extract(String dataUri,
          {required TokenConfirmation confirm}) =>
      _run('detect', {'image': dataUri, 'request_id': requestId()}, 1, confirm);

  Future<Map<String, dynamic>?> enhance(String jobId, List<String> itemIds,
      {required TokenConfirmation confirm}) {
    if (itemIds.isEmpty ||
        itemIds.length > 20 ||
        itemIds.toSet().length != itemIds.length) {
      throw ArgumentError('Select 1–20 unique items');
    }
    return _run(
        'generate',
        {'job_id': jobId, 'item_ids': List<String>.of(itemIds)},
        itemIds.length * 2,
        confirm);
  }

  /// One garment = one token. Call recover to poll; never submit a second job.
  Future<Map<String, dynamic>?> tryOn(
          String personDataUri, String garmentDataUri,
          {required TokenConfirmation confirm}) =>
      _run(
          'tryon',
          {
            'person_image': personDataUri,
            'clothing_image': garmentDataUri,
            'request_id': requestId()
          },
          1,
          confirm);

  /// Clear only after the UI has durably saved/displayed the completed result.
  Future<void> acknowledge() async {
    if (_busy) throw const StyleMuseApiException('operation_in_progress');
    final saved = await storage.read(pendingKey);
    if (saved != null && (jsonDecode(saved) as Map)['phase'] != 'done') {
      throw const StyleMuseApiException('pending_operation_requires_recovery');
    }
    await storage.delete(pendingKey);
    _pending = null;
  }

  Future<Map<String, dynamic>?> recover() async {
    if (_busy) throw const StyleMuseApiException('operation_in_progress');
    _busy = true;
    _cancelled = false;
    try {
      final saved = await storage.read(pendingKey);
      if (saved == null) return null;
      _pending = jsonDecode(saved) as Map<String, dynamic>;
      if (_pending!['owner'] != await _owner())
        throw const StyleMuseApiException('pending_account_mismatch');
      if (_pending!['phase'] == 'done')
        return Map<String, dynamic>.from(_pending!['result'] as Map);
      if (_pending!['action'] == 'tryon' && _pending!['job_id'] != null) {
        final status = await api
            .post('/api/tryon/status', {'job_id': _pending!['job_id']});
        if (status['state'] == 'done' || status['state'] == 'failed') {
          _pending!['phase'] = 'done';
          _pending!['result'] = status;
          await _save();
        }
        return status;
      }
      final inputs = Map<String, dynamic>.from(_pending!['inputs'] as Map);
      final response = await api.post('/api/operations/recover', {
        'action': _pending!['action'],
        if (_pending!['action'] != 'generate')
          'request_id': inputs['request_id']
        else ...{'job_id': inputs['job_id'], 'item_ids': inputs['item_ids']},
      });
      if (_pending!['action'] == 'tryon' && response['state'] == 'pending') {
        _pending!['phase'] = 'polling';
        _pending!['job_id'] = response['job_id'];
        await _save();
        return _cancelled ? null : response;
      }
      if (response['state'] != 'done')
        throw const StyleMuseApiException('request_ambiguous_no_retry');
      final result = Map<String, dynamic>.from(response['result'] as Map);
      _pending!['phase'] = 'done';
      _pending!['result'] = result;
      await _save();
      return _cancelled ? null : result;
    } finally {
      _busy = false;
    }
  }

  Future<Map<String, dynamic>?> _run(String action, Map<String, dynamic> inputs,
      int tokens, TokenConfirmation confirm) async {
    if (_busy) throw const StyleMuseApiException('operation_in_progress');
    _busy = true;
    _cancelled = false;
    try {
      final saved = await storage.read(pendingKey);
      if (saved != null)
        throw const StyleMuseApiException(
            'pending_operation_requires_recovery');
      final owner = await _owner();
      final quote =
          await api.post('/api/quote', {'action': action, 'inputs': inputs});
      if (quote['style_tokens'] != tokens)
        throw const StyleMuseApiException('token_quote_mismatch');
      if (_cancelled || !await confirm(tokens) || _cancelled) return null;
      _pending = {
        'action': action,
        'inputs': inputs,
        'phase': 'submitted',
        'owner': owner
      };
      await _save(); // Failure here MUST prevent inference.
      if (_cancelled) {
        await storage.delete(pendingKey);
        _pending = null;
        return null;
      }
      final result = await api.post('/api/$action', {
        ...inputs,
        'quote_id': quote['quote_id'],
        'confirmed': true,
        'max_total_usd': quote['estimated_cost_usd'],
        if (action == 'generate') 'approved_style_tokens': tokens
      });
      _pending!['phase'] = action == 'tryon' && result['state'] == 'pending'
          ? 'polling'
          : 'done';
      if (action == 'tryon') _pending!['job_id'] = result['job_id'];
      _pending!['result'] = result;
      await _save();
      return _cancelled ? null : result;
    } finally {
      _busy = false;
    }
  }
}
