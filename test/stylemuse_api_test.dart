import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/stylemuse_api.dart';

class MemorySecureStore implements SecureStore {
  final values = <String, String>{};
  Future<void> Function(String key)? beforeWrite;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    await beforeWrite?.call(key);
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeTransport implements ApiTransport {
  String userId = 'u';
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];
  final headers = <Map<String, String>>[];
  Future<ApiResponse> Function(String, Map<String, dynamic>)? handler;
  @override
  Future<ApiResponse> post(
      Uri url, Map<String, String> h, Map<String, dynamic> body) async {
    calls.add(url.path);
    bodies.add(body);
    headers.add(h);
    if (url.path == '/api/session')
      return ApiResponse(200, {'enabled': true},
          sessionCookie: '__Host-stylemuse_session=secret');
    if (url.path == '/api/account')
      return ApiResponse(200, {
        'user': {'provider': 'google', 'id': userId},
        'balance': 100
      });
    return handler!(url.path, body);
  }
}

void main() {
  test('secure storage write failure prevents paid submission', () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    s.beforeWrite = (key) async {
      if (key == TokenWorkflowController.pendingKey)
        throw StateError('keystore locked');
    };
    t.handler = (p, b) async => ApiResponse(
        200, {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.05});
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    await expectLater(
        c.extract('image', confirm: (_) async => true), throwsStateError);
    expect(t.calls.contains('/api/detect'), isFalse);
  });
  test('declined confirmation and mismatched quote cannot spend', () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    var tokens = 1;
    t.handler = (p, b) async => ApiResponse(200,
        {'quote_id': 'q', 'style_tokens': tokens, 'estimated_cost_usd': 0.05});
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    expect(await c.extract('image', confirm: (_) async => false), isNull);
    tokens = 2;
    await expectLater(
        c.extract('image', confirm: (_) async => true),
        throwsA(isA<StyleMuseApiException>()
            .having((e) => e.code, 'code', 'token_quote_mismatch')));
    expect(t.calls.contains('/api/detect'), isFalse);
  });
  test(
      'expired quote is not retried and a pending operation blocks a second charge',
      () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    t.handler = (p, b) async => p == '/api/quote'
        ? ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.05})
        : ApiResponse(403, {'error': 'quote_invalid_or_expired'});
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    await expectLater(c.extract('image', confirm: (_) async => true),
        throwsA(isA<StyleMuseApiException>()));
    await expectLater(
        c.extract('image', confirm: (_) async => true),
        throwsA(isA<StyleMuseApiException>().having(
            (e) => e.code, 'code', 'pending_operation_requires_recovery')));
    expect(t.calls.where((p) => p == '/api/detect').length, 1);
  });
  test('enhancement lost response uses read-only item recovery', () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    t.handler = (p, b) async {
      if (p == '/api/quote')
        return ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 2, 'estimated_cost_usd': 0.1});
      if (p == '/api/generate') throw TimeoutException('lost');
      expect(b, {
        'action': 'generate',
        'job_id': 'j',
        'item_ids': ['a']
      });
      return ApiResponse(200, {
        'state': 'done',
        'result': {
          'items': [
            {'id': 'a', 'image': 'enhanced'}
          ]
        }
      });
    };
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    await expectLater(c.enhance('j', ['a'], confirm: (_) async => true),
        throwsA(isA<TimeoutException>()));
    expect((await c.recover())?['items'], isNotEmpty);
    expect(t.calls.where((p) => p == '/api/generate').length, 1);
  });
  test('cancel during durable save still prevents paid submission', () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    final writing = Completer<void>();
    final release = Completer<void>();
    s.beforeWrite = (key) async {
      if (key == TokenWorkflowController.pendingKey && !writing.isCompleted) {
        writing.complete();
        await release.future;
      }
    };
    t.handler = (p, b) async => p == '/api/quote'
        ? ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.05})
        : ApiResponse(200, {'job_id': 'wrong'});
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    final work = c.extract('image', confirm: (_) async => true);
    await writing.future;
    c.cancel();
    release.complete();
    expect(await work, isNull);
    expect(t.calls.contains('/api/detect'), isFalse);
    expect(s.values[TokenWorkflowController.pendingKey], isNull);
  });
  test('a different signed-in account cannot read cached completed result',
      () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    t.handler = (p, b) async => p == '/api/quote'
        ? ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.05})
        : ApiResponse(200, {'job_id': 'private', 'items': []});
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    await c.extract('image', confirm: (_) async => true);
    t.userId = 'different';
    await expectLater(
        c.recover(),
        throwsA(isA<StyleMuseApiException>()
            .having((e) => e.code, 'code', 'pending_account_mismatch')));
  });
  test(
      'lost tryon submission is recovered by original request id, not resubmitted',
      () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    t.handler = (p, b) async {
      if (p == '/api/quote')
        return ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.04});
      if (p == '/api/tryon') throw TimeoutException('lost');
      if (p == '/api/operations/recover') {
        expect(b, {'action': 'tryon', 'request_id': 'original'});
        return ApiResponse(
            200, {'state': 'pending', 'job_id': 'tryon-original'});
      }
      expect(b['job_id'], 'tryon-original');
      return ApiResponse(200, {
        'state': 'done',
        'job_id': 'tryon-original',
        'image': 'https://fal.media/a.png'
      });
    };
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t),
        storage: s,
        requestId: () => 'original');
    await expectLater(c.tryOn('p', 'c', confirm: (_) async => true),
        throwsA(isA<TimeoutException>()));
    final restored = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    expect((await restored.recover())?['state'], 'pending');
    expect((await restored.recover())?['state'], 'done');
    expect(t.calls.where((p) => p == '/api/tryon').length, 1);
  });
  test(
      'cancel after submission retains late result but suppresses UI continuation',
      () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    final submitted = Completer<void>();
    final response = Completer<ApiResponse>();
    t.handler = (p, b) async {
      if (p == '/api/quote')
        return ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.05});
      submitted.complete();
      return response.future;
    };
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    final work = c.extract('image', confirm: (_) async => true);
    await submitted.future;
    c.cancel();
    response.complete(ApiResponse(200, {'job_id': 'late', 'items': []}));
    expect(await work, isNull);
    expect((await c.recover())?['job_id'], 'late');
  });
  test(
      'cancellation while confirmation is open never submits or persists paid work',
      () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    t.handler = (p, b) async => ApiResponse(
        200, {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.05});
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    final confirmation = Completer<bool>();
    final shown = Completer<void>();
    final work = c.extract('image', confirm: (_) {
      shown.complete();
      return confirmation.future;
    });
    await shown.future;
    c.cancel();
    confirmation.complete(true);
    expect(await work, isNull);
    expect(t.calls.contains('/api/detect'), false);
    expect(s.values['stylemuse.pending'], isNull);
  });
  test('tryon is one token per garment and restart polls same job', () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    t.handler = (p, b) async {
      if (p == '/api/quote')
        return ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.04});
      if (p == '/api/tryon')
        return ApiResponse(200, {'job_id': 'tryon-j', 'state': 'pending'});
      expect(p, '/api/tryon/status');
      expect(b, {'job_id': 'tryon-j'});
      return ApiResponse(200, {
        'job_id': 'tryon-j',
        'state': 'done',
        'image': 'https://fal.media/result.png'
      });
    };
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    final r = await c.tryOn('person', 'garment', confirm: (n) async {
      expect(n, 1);
      return true;
    });
    expect(r?['state'], 'pending');
    final restored = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    expect(
        (await restored.recover())?['image'], 'https://fal.media/result.png');
    expect(t.calls.where((p) => p == '/api/tryon').length, 1);
  });
  test(
      'lost extraction response recovers after restart without paid resubmission',
      () async {
    final s = MemorySecureStore();
    final t = FakeTransport();
    t.handler = (p, b) async {
      if (p == '/api/quote')
        return ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.05});
      if (p == '/api/detect') throw TimeoutException('lost response');
      expect(p, '/api/operations/recover');
      expect(b, {'action': 'detect', 'request_id': 'r'});
      return ApiResponse(200, {
        'state': 'done',
        'result': {'job_id': 'recovered', 'items': []}
      });
    };
    final a = StyleMuseApi(storage: s, transport: t);
    await expectLater(
        TokenWorkflowController(api: a, storage: s, requestId: () => 'r')
            .extract('image', confirm: (_) async => true),
        throwsA(isA<TimeoutException>()));
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: s, transport: t), storage: s);
    expect((await c.recover())?['job_id'], 'recovered');
    expect(t.calls.where((p) => p == '/api/detect').length, 1);
    await c.acknowledge();
    expect(s.values['stylemuse.pending'], isNull);
  });
  test('enhance two items approves four tokens explicitly', () async {
    final store = MemorySecureStore();
    final t = FakeTransport();
    t.handler = (p, b) async {
      if (p == '/api/quote') {
        expect(b['action'], 'generate');
        return ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 4, 'estimated_cost_usd': 0.2});
      }
      expect(b['approved_style_tokens'], 4);
      expect(b['item_ids'], ['a', 'b']);
      return ApiResponse(200, {
        'items': [
          {'id': 'a', 'image': 'result'}
        ]
      });
    };
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: store, transport: t), storage: store);
    expect(
        (await c.enhance('j', ['a', 'b'], confirm: (n) async {
          expect(n, 4);
          return true;
        }))?['items'],
        isNotEmpty);
  });
  test(
      'extraction quotes one token, persists before paid POST, and returns actual server result',
      () async {
    final store = MemorySecureStore();
    final t = FakeTransport();
    t.handler = (p, b) async {
      if (p == '/api/quote')
        return ApiResponse(200,
            {'quote_id': 'q', 'style_tokens': 1, 'estimated_cost_usd': 0.05});
      expect(
          jsonDecode(store.values['stylemuse.pending']!)['phase'], 'submitted');
      expect(b['confirmed'], true);
      expect(b['max_total_usd'], 0.05);
      return ApiResponse(200, {'job_id': 'j', 'items': <dynamic>[]});
    };
    final c = TokenWorkflowController(
        api: StyleMuseApi(storage: store, transport: t),
        storage: store,
        requestId: () => 'request_1');
    final result =
        await c.extract('data:image/png;base64,AA==', confirm: (tokens) async {
      expect(tokens, 1);
      return true;
    });
    expect(result?['job_id'], 'j');
    expect(
        t.calls, ['/api/session', '/api/account', '/api/quote', '/api/detect']);
    expect(jsonDecode(store.values['stylemuse.pending']!)['phase'], 'done');
  });
  test(
      'bootstrap persists cookie securely and Android ID token is verified by server',
      () async {
    final store = MemorySecureStore();
    final transport = FakeTransport();
    transport.handler = (path, body) async => ApiResponse(200, {
          'user': {'id': 'u'},
          'balance': 8
        });
    final api = StyleMuseApi(storage: store, transport: transport);
    final account = await api.signInGoogle('signed');
    expect(account['balance'], 8);
    expect(transport.calls, ['/api/session', '/api/auth/google/android']);
    expect(transport.bodies.last, {'credential': 'signed'});
    expect(transport.headers.last['Cookie'], '__Host-stylemuse_session=secret');
    expect(transport.headers.last['Origin'], 'https://yasinaday.github.io');
    expect(store.values.values.any((v) => v.contains('signed')), isFalse);
    final restored = StyleMuseApi(storage: store, transport: transport);
    await restored.account();
    expect(transport.calls.where((p) => p == '/api/session').length, 1);
  });
}
