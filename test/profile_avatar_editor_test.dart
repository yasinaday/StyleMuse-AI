import 'package:flutter_test/flutter_test.dart';
import 'package:stylemuse_ai/profile_editor.dart';
import 'package:stylemuse_ai/closet.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('server failure keeps editor open and local profile unchanged',
      (tester) async {
    final store = ClosetStore(memory: true);
    await store.updateProfile({'google:a:name': 'Before'});
    await tester.pumpWidget(MaterialApp(
        home: ProfileEditor(
      store: store,
      personal: true,
      profilePrefix: 'google:a:',
      initialName: 'Before',
      savePersonal: (values) async => throw StateError('offline'),
    )));
    await tester.enterText(find.byKey(const Key('profile-name')), 'After');
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();
    expect(store.profile['google:a:name'], 'Before');
    expect(find.byType(ProfileEditor), findsOneWidget);
    expect(find.text('Kaydedilemedi.'), findsOneWidget);
  });
}
