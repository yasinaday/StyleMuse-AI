import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';

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
  final paths = <String>[];
  final Map<String, Map<String, dynamic>> replies;
  FixtureTransport(this.replies);
  @override
  Future<ApiResponse> post(
      Uri url, Map<String, String> headers, Map<String, dynamic> body) async {
    paths.add(url.path);
    if (!replies.containsKey(url.path))
      throw StateError('Unexpected endpoint ${url.path}');
    return ApiResponse(200, replies[url.path]!,
        sessionCookie: url.path == '/api/session'
            ? '__Host-stylemuse_session=fixture'
            : null);
  }
}

void main() {
  testWidgets(
      'native mannequin performs consented try-on and saves its result as an outfit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 40, height: 60)))}';
    final store = ClosetStore(memory: true);
    await store.addGarment(image: data, category: 'Elbise');
    final secure = MemorySecure();
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'}
      },
      '/api/quote': {
        'quote_id': 'q',
        'style_tokens': 1,
        'estimated_cost_usd': 0.01
      },
      '/api/tryon': {'state': 'done', 'job_id': 'job', 'image': data}
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mankenim').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tryon-start')), findsOneWidget);
    final mannequinScroll = find
        .descendant(
            of: find.byKey(const Key('mannequin-page')),
            matching: find.byType(Scrollable))
        .first;
    await tester.drag(mannequinScroll, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('try-garment-0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('tryon-start')));
    await tester.tap(find.byKey(const Key('tryon-start')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(transport.paths, isNot(contains('/api/tryon')));
    await tester.tap(find.byKey(const Key('confirm-tokens')));
    await tester.pumpAndSettle();
    expect(transport.paths, contains('/api/tryon'));
    expect(find.byKey(const Key('save-tryon')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-tryon')));
    await tester.pumpAndSettle();
    expect(store.looks.single['aiImage'], isNotNull);
    expect(
        secure.values.containsKey(TokenWorkflowController.pendingKey), isFalse);
  });
  testWidgets(
      'review enhancement uses two tokens per selected item and preserves draft until saved',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final original =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
    final enhanced =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 30, height: 40)))}';
    final store = ClosetStore(memory: true);
    await store.saveReview({
      'job_id': 'job',
      'items': [
        {'id': 'p1', 'category': 'Elbise', 'preview': original}
      ]
    });
    final secure = MemorySecure();
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'}
      },
      '/api/quote': {
        'quote_id': 'q',
        'style_tokens': 2,
        'estimated_cost_usd': 0.01
      },
      '/api/generate': {
        'items': [
          {'id': 'p1', 'image': enhanced}
        ]
      }
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('extract-photo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('enhance-analysis')), findsOneWidget);
    await tester.tap(find.byKey(const Key('enhance-analysis')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(transport.paths, isNot(contains('/api/generate')));
    await tester.tap(find.byKey(const Key('confirm-tokens')));
    await tester.pumpAndSettle();
    expect(store.items, isEmpty);
    expect(store.review, isNotNull);
    await tester.tap(find.byKey(const Key('accept-analysis')));
    await tester.pumpAndSettle();
    expect(store.items.single.image, enhanced);
    expect(store.review, isNull);
    expect(
        secure.values.containsKey(TokenWorkflowController.pendingKey), isFalse);
  });
  testWidgets(
      'AI extraction asks token consent and saves reviewed results before acknowledgement',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 60)));
    final data = 'data:image/jpeg;base64,${base64Encode(image)}';
    final secure = MemorySecure();
    final transport = FixtureTransport({
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'}
      },
      '/api/session': {},
      '/api/quote': {
        'quote_id': 'q',
        'style_tokens': 1,
        'estimated_cost_usd': 0.01
      },
      '/api/detect': {
        'job_id': 'job',
        'items': [
          {'id': 'part', 'category': 'Elbise', 'preview': data}
        ]
      }
    });
    final store = ClosetStore(memory: true);
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: secure, transport: transport),
        pickPhoto: (_) async => image));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('extract-photo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('extract-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crop-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(transport.paths, contains('/api/quote'));
    expect(transport.paths, isNot(contains('/api/detect')));
    await tester.tap(find.byKey(const Key('confirm-tokens')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('analysis-review')), findsOneWidget);
    expect(store.items, isEmpty);
    await tester.tap(find.byKey(const Key('accept-analysis')));
    await tester.pumpAndSettle();
    expect(store.items.single.category, 'Elbise');
    expect(
        secure.values.containsKey(TokenWorkflowController.pendingKey), isFalse);
    expect(transport.paths.where((x) => x == '/api/detect'), hasLength(1));
  });
  testWidgets(
      'account balance is read through the actual injected API only on user action',
      (tester) async {
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'name': 'Ada', 'email': 'ada@example.test'},
        'balance': 17
      }
    });
    final api = StyleMuseApi(storage: MemorySecure(), transport: transport);
    await tester
        .pumpWidget(StyleMuseApp(store: ClosetStore(memory: true), api: api));
    await tester.pumpAndSettle();
    expect(transport.paths, isEmpty);
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-refresh')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-refresh')));
    await tester.pumpAndSettle();
    expect(transport.paths, ['/api/session', '/api/account']);
    expect(find.textContaining('17'), findsWidgets);
    expect(find.text('ada@example.test'), findsOneWidget);
  });
}
