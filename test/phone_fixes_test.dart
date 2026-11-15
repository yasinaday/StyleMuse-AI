import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/stylemuse_api.dart';
import 'ui_api_test.dart' show MemorySecure, FixtureTransport;

void main() {
  testWidgets('empty mannequin CTA opens Giysiler without API calls',
      (tester) async {
    final transport = FixtureTransport({});
    await tester.pumpWidget(StyleMuseApp(
        store: ClosetStore(memory: true),
        api: StyleMuseApi(storage: MemorySecure(), transport: transport)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mankenim').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('mannequin-add-clothes')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('mannequin-add-clothes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('extract-photo')), findsOneWidget);
    expect(transport.paths, isEmpty);
  });

  testWidgets('offline analysis offers safe error without nonexistent recovery',
      (tester) async {
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {'user': null}
    });
    await tester.pumpWidget(StyleMuseApp(
        store: ClosetStore(memory: true),
        api: StyleMuseApi(storage: MemorySecure(), transport: transport)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recover-operation')), findsNothing);
  });
  testWidgets(
      'anonymous cropped analysis requests login without offering nonexistent recovery',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final transport = FixtureTransport({
      '/api/session': {},
      '/api/account': {'user': null}
    });
    final store = ClosetStore(memory: true);
    await tester.pumpWidget(StyleMuseApp(
        store: store,
        api: StyleMuseApi(storage: MemorySecure(), transport: transport),
        pickPhoto: (_) async => Uint8List.fromList(
            img.encodeJpg(img.Image(width: 40, height: 60)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giysiler').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('extract-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crop-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('AI analizi için Google hesabınla giriş yap.'),
        findsOneWidget);
    expect(find.byKey(const Key('recover-operation')), findsNothing);
    expect(find.textContaining('Kurtar düğmesiyle'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(transport.paths, isNot(contains('/api/detect')));
  });
}
