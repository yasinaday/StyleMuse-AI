import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';

void main() {
  testWidgets('outfits uses the approved idea action label', (tester) async {
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kombinler').last);
    await tester.pumpAndSettle();
    expect(find.text('Bana fikir ver'), findsOneWidget);
  });
  testWidgets('empty wardrobe still exposes approved copy and category filters',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(StyleMuseApp(store: ClosetStore(memory: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    expect(find.text('Yapay zekâ ile kıyafetleri ayır'), findsOneWidget);
    expect(find.text('Fotoğraf seç ve dolabıma ekle'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Tümü'), findsOneWidget);
    final filters = find
        .ancestor(
            of: find.byType(FilterChip).first, matching: find.byType(ListView))
        .first;
    await tester.drag(filters, const Offset(-1100, 0));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Diğer'), findsOneWidget);
  });
}
