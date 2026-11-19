import 'dart:convert';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'pending_recovery_ui_test.dart' show RecoveryStore;
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

class DelayedRecoveryStore extends ClosetStore {
  DelayedRecoveryStore() : super(memory: true);
  final loaded = Completer<void>();
  @override
  Future<void> load() => loaded.future;
}

class BlockingRecoveryTransport extends FixtureTransport {
  BlockingRecoveryTransport(super.replies);
  final release = Completer<void>();
  @override
  Future<ApiResponse> post(
      Uri url, Map<String, String> headers, Map<String, dynamic> body) async {
    if (url.path == '/api/operations/recover') await release.future;
    return super.post(url, headers, body);
  }
}

void main() {
  testWidgets('restart automatically recovers original job without paid submit',
      (tester) async {
    final secure = MemorySecure();
    secure.values[TokenWorkflowController.pendingKey] = jsonEncode({
      'owner': 'google:fixture-user',
      'action': 'detect',
      'phase': 'submitted',
      'inputs': {'request_id': 'original'},
    });
    final store = ClosetStore(memory: true);
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'}
      },
      '/api/operations/recover': {
        'state': 'done',
        'result': {'job_id': 'original-job', 'items': []}
      },
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pumpAndSettle();
    expect(store.review?['job_id'], 'original-job');
    expect(find.byKey(const Key('analysis-review')), findsOneWidget);
    expect(
        transport.paths
            .where((x) => x.contains('/extract') || x.contains('/generate')),
        isEmpty);
    expect(secure.values[TokenWorkflowController.pendingKey], isNull);
  });
  testWidgets(
      'failed recovery shows error beside retry in wardrobe not global header',
      (tester) async {
    final secure = MemorySecure();
    final store = RecoveryStore(secure)..failSave = true;
    secure.values[TokenWorkflowController.pendingKey] = jsonEncode({
      'owner': 'google:fixture-user',
      'action': 'detect',
      'phase': 'done',
      'inputs': {'request_id': 'original'},
      'result': {'job_id': 'job', 'items': []},
    });
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'}
      }
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('recover-operation')), findsOneWidget);
    expect(find.text('İşlem tamamlanamadı. Kurtar düğmesiyle kontrol et.'),
        findsOneWidget);
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recover-operation')), findsNothing);
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    store.failSave = false;
    await tester.tap(find.byKey(const Key('recover-operation')));
    await tester.pumpAndSettle();
    expect(store.review?['job_id'], 'job');
    expect(secure.values[TokenWorkflowController.pendingKey], isNull);
  });

  testWidgets('restart recovery waits for durable closet load before saving',
      (tester) async {
    final secure = MemorySecure();
    final store = DelayedRecoveryStore();
    secure.values[TokenWorkflowController.pendingKey] = jsonEncode({
      'owner': 'google:fixture-user',
      'action': 'detect',
      'phase': 'done',
      'inputs': {'request_id': 'original'},
      'result': {'job_id': 'job', 'items': []},
    });
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'}
      }
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pumpAndSettle();
    expect(store.review, isNull);
    expect(secure.values[TokenWorkflowController.pendingKey], isNotNull);
    store.loaded.complete();
    await tester.pumpAndSettle();
    expect(store.review?['job_id'], 'job');
  });

  testWidgets(
      'restart restores processing photo scanner and stops it after recovery',
      (tester) async {
    final secure = MemorySecure();
    final image =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
    secure.values[TokenWorkflowController.pendingKey] = jsonEncode({
      'owner': 'google:fixture-user',
      'action': 'detect',
      'phase': 'submitted',
      'inputs': {'request_id': 'original', 'image': image},
    });
    final store = ClosetStore(memory: true);
    final transport = BlockingRecoveryTransport({
      '/api/session': {},
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'}
      },
      '/api/operations/recover': {
        'state': 'done',
        'result': {'job_id': 'job', 'items': []}
      },
    });
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('processing-scanner')), findsOneWidget);
    transport.release.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('processing-scanner')), findsNothing);
    expect(store.review?['sourceImage'], image);
  });
  testWidgets('resume retries retained job automatically without a new submit', (tester) async {
    final secure = MemorySecure();
    final store = RecoveryStore(secure)..failSave = true;
    secure.values[TokenWorkflowController.pendingKey] = jsonEncode({
      'owner': 'google:fixture-user', 'action': 'detect', 'phase': 'done',
      'inputs': {'request_id': 'original'}, 'result': {'job_id': 'job', 'items': []},
    });
    final transport = FixtureTransport({'/api/session': {}, '/api/account': {'user': {'provider': 'google', 'id': 'fixture-user'}}});
    await tester.pumpWidget(StyleMuseApp(store: store, api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pumpAndSettle();
    expect(store.review, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    store.failSave = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(store.review?['job_id'], 'job');
    expect(transport.paths.where((p) => p != '/api/session' && p != '/api/account'), isEmpty);
  });
  testWidgets('pending recovery keeps stage spinner until terminal status', (tester) async {
    final secure = MemorySecure();
    final store = ClosetStore(memory: true);
    final image = 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
    secure.values[TokenWorkflowController.pendingKey] = jsonEncode({
      'owner': 'google:fixture-user', 'action': 'tryon', 'phase': 'polling', 'job_id': 'original-job',
      'inputs': {'request_id': 'original'},
    });
    final transport = FixtureTransport({'/api/session': {}, '/api/account': {'user': {'provider': 'google', 'id': 'fixture-user'}}, '/api/tryon/status': {'state': 'pending'}});
    await tester.pumpWidget(StyleMuseApp(store: store, api: StyleMuseApi(storage: secure, transport: transport)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    transport.replies['/api/tryon/status'] = {'state': 'done', 'image': image};
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(store.tryonResult, startsWith('data:image/'));
    expect(img.decodeImage(base64Decode(store.tryonResult!.split(',').last))!.width, 20);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(transport.bodies['/api/tryon/status']!.every((body) => body['job_id'] == 'original-job'), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

}
