import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';

void main() {
  testWidgets('footer uses the five approved web outline symbols',
      (tester) async {
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('web-nav-icon-$i')), findsOneWidget);
    }
  });
}
