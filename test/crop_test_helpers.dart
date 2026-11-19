import 'package:flutter_test/flutter_test.dart';

/// Cropping uses compute(); fake-time settling does not wait for its isolate.
Future<void> waitForCropReturn(WidgetTester tester, Finder next) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    if (next.evaluate().isNotEmpty) return;
  }
  expect(next, findsWidgets,
      reason: 'Crop isolate did not return to the next screen');
}
