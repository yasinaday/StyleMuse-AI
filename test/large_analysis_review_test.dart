import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stylemuse_ai/large_analysis_review.dart';
import 'package:stylemuse_ai/closet.dart';

void main() {
  testWidgets(
      'review gives product photos room and retains compact actions on phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ClosetStore(memory: true)
      ..review = {
        'items': [
          {'id': 'a', 'category': 'Elbise', 'preview': ''}
        ]
      };
    await tester
        .pumpWidget(MaterialApp(home: LargeAnalysisReviewPage(store: store)));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byKey(const Key('review-product-photo-0'))).height,
        greaterThanOrEqualTo(200));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seçilen parçaları incele'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accept-analysis')), findsOneWidget);
    expect(find.text('Analizi iptal et'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
