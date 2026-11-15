import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:stylemuse_ai/main.dart';
import 'package:stylemuse_ai/outfit_composer.dart';

void main() {
  testWidgets('shell planning selections initialize composer and saved outfit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ClosetStore(memory: true);
    final bytes = img.encodePng(img.Image(width: 20, height: 20));
    await store.addGarment(
        image: 'data:image/png;base64,${base64Encode(bytes)}',
        category: 'Elbise');
    await tester.pumpWidget(StyleMuseApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kombinler').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akşam yemeği').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Romantik').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bana fikir ver'));
    await tester.pumpAndSettle();

    final composerFields = find.descendant(
        of: find.byType(OutfitComposer),
        matching: find.byType(DropdownButtonFormField<String>));
    expect(tester.state<FormFieldState<String>>(composerFields.at(0)).value,
        'Akşam yemeği');
    expect(tester.state<FormFieldState<String>>(composerFields.at(1)).value,
        'Romantik');
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.tap(find.byKey(const Key('save-look')));
    await tester.pumpAndSettle();
    expect(store.looks, hasLength(1));
    expect(store.looks.single['occasion'], 'Akşam yemeği');
    expect(store.looks.single['style'], 'Romantik');
    expect(tester.takeException(), isNull);
  });
}
