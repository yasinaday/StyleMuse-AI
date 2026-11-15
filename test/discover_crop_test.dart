import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';

void main() {
  testWidgets('Discover preserves the model head inside the hero viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    final model = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/home/model.webp');
    expect(
        tester.getTopLeft(model).dy,
        greaterThanOrEqualTo(
            tester.getTopLeft(find.byKey(const Key('discover-page'))).dy));
    expect(find.text('Stil Jetonu'), findsOneWidget);
  });
}
