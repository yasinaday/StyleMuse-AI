import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stylemuse_ai/processing_photo.dart';

void main() {
  testWidgets('scanner animates only while processing without fake percentages',
      (tester) async {
    Widget page(bool active) => MaterialApp(
        home: SizedBox(
            width: 300,
            height: 350,
            child: ProcessingPhoto(
                active: active,
                stage: 'Analiz ediliyor',
                child: const Placeholder())));
    await tester.pumpWidget(page(true));
    expect(find.byKey(const Key('processing-scanner')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('processing-scanner')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
