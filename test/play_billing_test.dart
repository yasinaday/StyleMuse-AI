import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/play_billing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stylemuse_ai/play_billing_packs.dart';

void main() {
  testWidgets('all five packs remain visible and disabled without Play prices',
      (tester) async {
    final c = PlayBillingController(
        verify: (product, token) async =>
            const PlayVerification(credited: false, consumed: false));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PlayBillingPacks(
                    controller: c,
                    buyLabel: 'Buy',
                    unavailableLabel: 'Unavailable',
                    statusLabel: (s) => s)))));
    for (final count in [10, 25, 50, 100, 200]) {
      expect(find.byKey(ValueKey('play-pack-$count')), findsOneWidget);
    }
    expect(
        tester
            .widgetList<FilledButton>(find.byType(FilledButton))
            .every((b) => b.onPressed == null),
        isTrue);
    c.dispose();
  });
  testWidgets('localized Play price is displayed without USD conversion',
      (tester) async {
    final c = PlayBillingController(
        verify: (product, token) async =>
            const PlayVerification(credited: true, consumed: true));
    c.products = [
      ProductDetails(
          id: 'tokens_10',
          title: 'Ten tokens',
          description: '',
          price: '₺99,99',
          rawPrice: 99.99,
          currencyCode: 'TRY')
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PlayBillingPacks(
                controller: c,
                buyLabel: 'Buy',
                unavailableLabel: 'Unavailable',
                statusLabel: (s) => s))));
    expect(find.text('₺99,99'), findsOneWidget);
    expect(find.textContaining('USD'), findsNothing);
    c.dispose();
  });
  test('credit requires confirmed server consumption', () async {
    var consumed = false;
    final c = PlayBillingController(
        verify: (product, token) async =>
            PlayVerification(credited: true, consumed: consumed));
    final p = PurchaseDetails(
        productID: 'tokens',
        verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'token',
            source: 'google_play'),
        transactionDate: null,
        status: PurchaseStatus.purchased);
    await c.handle(p);
    expect(c.state, 'retry_required');
    consumed = true;
    await c.recover();
    expect(c.state, 'credited');
    c.dispose();
  });
  test('pending and cancellation never verify or complete', () async {
    var calls = 0;
    final controller = PlayBillingController(verify: (p, t) async {
      calls++;
      return const PlayVerification(credited: true, consumed: true);
    });
    for (final status in [
      PurchaseStatus.pending,
      PurchaseStatus.canceled,
      PurchaseStatus.error
    ]) {
      await controller.handle(PurchaseDetails(
          productID: 'tokens',
          verificationData: PurchaseVerificationData(
              localVerificationData: '',
              serverVerificationData: 'token',
              source: 'google_play'),
          transactionDate: null,
          status: status));
    }
    expect(calls, 0);
  });
  test('server failure stays retryable and uncredited', () async {
    final controller = PlayBillingController(
        verify: (p, t) async => throw StateError('offline'));
    await controller.handle(PurchaseDetails(
        productID: 'tokens',
        verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'token',
            source: 'google_play'),
        transactionDate: null,
        status: PurchaseStatus.purchased));
    expect(controller.state, 'retry_required');
  });
}
