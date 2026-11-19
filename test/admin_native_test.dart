import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/admin_page.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'package:stylemuse_ai/admin_api.dart';

class FakeAdmin implements AdminApi {
  int reads = 0;
  bool denied = false;
  @override
  Future<Map<String, dynamic>> overview() async {
    if (denied)
      throw const StyleMuseApiException('token_load_admin_only', status: 403);
    reads++;
    return {
      'jobs': [
        {'id': 'failed-job', 'state': 'failed'},
        {
          'id': 'job-1',
          'state': 'done',
          'items': [
            {'id': 'blouse-1', 'category': 'top'}
          ]
        }
      ],
      'settings': {'inference_enabled': false}
    };
  }

  @override
  Future<Map<String, dynamic>> falCredit() async => {};
  @override
  Future<Map<String, dynamic>> replicateCredit() async => {};
  @override
  Future<Map<String, dynamic>> recordReplicateCredit(
          String amount, String id) async =>
      {};
  @override
  Future<Map<String, dynamic>> requestTokens(int amount) async =>
      {'request_id': 'request'};
  @override
  Future<Map<String, dynamic>> confirmTokens(String id, String code) async =>
      {'balance': 3};
}

void main() {
  testWidgets('admin page fetches safe history and reveals native job details',
      (tester) async {
    final api = FakeAdmin();
    await tester.pumpWidget(MaterialApp(home: AdminPage(api: api)));
    await tester.pumpAndSettle();
    expect(api.reads, 1);
    expect(find.text('Yönetici ayarları ve bildirimler'), findsOneWidget);
    expect(find.text('Başarısız ve yarım kalan işler'), findsOneWidget);
    expect(find.textContaining('job-1'), findsOneWidget);
    await tester.tap(find.textContaining('job-1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('blouse-1'), findsOneWidget);
  });
  testWidgets('revoked admin clears previously visible diagnostics',
      (tester) async {
    final api = FakeAdmin();
    await tester.pumpWidget(MaterialApp(home: AdminPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('job-1'), findsOneWidget);
    api.denied = true;
    await tester.tap(find.byTooltip('Durumu yenile'));
    await tester.pumpAndSettle();
    expect(find.textContaining('job-1'), findsNothing);
    expect(find.textContaining('doğrulanmış yönetici oturumu'), findsOneWidget);
  });
}
