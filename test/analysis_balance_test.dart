import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'crop_test_helpers.dart';
import 'ui_api_test.dart' show FixtureTransport, MemorySecure;
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';

class _UnavailableCreditTransport extends FixtureTransport {
  _UnavailableCreditTransport(super.replies);

  @override
  Future<ApiResponse> post(
      Uri url, Map<String, String> headers, Map<String, dynamic> body) async {
    if (url.path == '/api/quote') {
      paths.add(url.path);
      return ApiResponse(402, {'error': 'provider_credit_unavailable'});
    }
    return super.post(url, headers, body);
  }
}

void main() {
  testWidgets(
      'positive account balance is not blamed for unavailable provider credit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 60)));
    final secure = MemorySecure();
    final transport = _UnavailableCreditTransport({
      '/api/account': {
        'user': {'provider': 'google', 'id': 'fixture-user'},
        'balance': 516,
        'plan': 'Premium hesap'
      },
      '/api/session': {},
      '/api/quote': {
        'quote_id': 'q',
        'style_tokens': 1,
        'estimated_cost_usd': 0.01
      },
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
    await waitForCropReturn(tester, find.text('AI ile analiz et'));
    expect(transport.paths, isEmpty);
    await tester.tap(find.text('AI ile analiz et'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(transport.paths, contains('/api/quote'));
    expect(transport.paths, isNot(contains('/api/detect')));
    await tester.pumpAndSettle();
    expect(find.text('Analiz için sağlayıcı kredisi doğrulanamadı.'),
        findsOneWidget);
    expect(find.text('Bu işlem için yeterli Stil Jetonu yok.'), findsNothing);
    expect(find.byKey(const Key('confirm-tokens')), findsNothing);
    expect(transport.paths, isNot(contains('/api/detect')));
    expect(
        secure.values.containsKey(TokenWorkflowController.pendingKey), isFalse);
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('516 Stil Jetonu ›'), findsOneWidget);
    expect(find.text('Premium hesap'), findsOneWidget);
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    transport.replies['/api/account'] = {
      ...transport.replies['/api/account']!,
      'balance': 515
    };
    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('515 Stil Jetonu ›'), findsOneWidget);
  });
}
