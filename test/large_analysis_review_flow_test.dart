import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image/image.dart' as img;
import 'package:stylemuse_ai/large_analysis_review.dart';
import 'package:stylemuse_ai/closet.dart';

void main() {
  testWidgets(
      'analysis requires explicit product selection and saves only edited selected product',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image =
        'data:image/jpeg;base64,${base64Encode(img.encodeJpg(img.Image(width: 20, height: 30)))}';
    final store = ClosetStore(memory: true);
    await store.saveReview({
      'sourceImage': image,
      'job_id': 'fixture',
      'items': [
        {'id': 'one', 'category': 'top', 'preview': image},
        {'id': 'two', 'category': 'bag', 'preview': image},
      ]
    });
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              LargeAnalysisReviewPage(store: store))),
                  child: const Text('Open'),
                )))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('0 ürün seçili'), findsOneWidget);
    expect(find.byKey(const Key('accept-analysis')), findsNothing);
    expect(store.items, isEmpty);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seçilen parçaları incele'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-category-0')), findsNothing);
    expect(find.byKey(const Key('review-category-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-category-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aksesuar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ürün seçimine geri dön'));
    await tester.pumpAndSettle();
    expect(find.text('1 ürün seçili'), findsOneWidget);
    await tester.tap(find.text('Seçilen parçaları incele'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-analysis')));
    await tester.pumpAndSettle();
    expect(store.items.single.category, 'Aksesuar');
    expect(store.items.single.image, image);
    expect(store.review, isNull);
    expect(tester.takeException(), isNull);
  });
}
