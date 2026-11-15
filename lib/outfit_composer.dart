import 'package:material_ui/material_ui.dart';
import 'closet.dart';
import 'main.dart' show SmText, LocalStrings, photo;
import 'localization.dart';

class OutfitComposer extends StatefulWidget {
  const OutfitComposer(
      {super.key,
      required this.store,
      this.initialOccasion = 'Günlük',
      this.initialStyle = 'Rahat ve şık'});
  final ClosetStore store;
  final String initialOccasion, initialStyle;
  @override
  State<OutfitComposer> createState() => _OutfitComposerState();
}

class _OutfitComposerState extends State<OutfitComposer> {
  final selected = <String>{};
  late String occasion, style;
  @override
  void initState() {
    super.initState();
    occasion = widget.initialOccasion;
    style = widget.initialStyle;
  }

  bool saving = false;
  String? error;
  String tr(String s) => translate(s, widget.store.language);
  @override
  Widget build(BuildContext context) => LocalStrings(
      language: widget.store.language,
      child: Scaffold(
        appBar: AppBar(title: const SmText('Kombin oluştur')),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: ListView(padding: const EdgeInsets.all(20), children: [
            DropdownButtonFormField<String>(
                initialValue: occasion,
                decoration:
                    InputDecoration(labelText: tr('Nereye gidiyorsun?')),
                items: [
                  for (final value in [
                    'Günlük',
                    'İş / Ofis',
                    'Akşam yemeği',
                    'Özel davet'
                  ])
                    DropdownMenuItem(value: value, child: SmText(value))
                ],
                onChanged: (x) => setState(() => occasion = x!)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: style,
                decoration: InputDecoration(labelText: tr('Tarzın')),
                items: [
                  for (final value in [
                    'Rahat ve şık',
                    'Minimal',
                    'Romantik',
                    'Modern klasik'
                  ])
                    DropdownMenuItem(value: value, child: SmText(value))
                ],
                onChanged: (x) => setState(() => style = x!)),
            const SizedBox(height: 16),
            const SmText(
                'Kombin için üst ve alt giyim ya da elbise seçmelisin.'),
            const SizedBox(height: 12),
            if (widget.store.items.isEmpty)
              const SmText(
                  'Dolabın henüz boş. İlk kıyafetini ekleyerek başla.'),
            for (final item in widget.store.items)
              Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                      value: selected.contains(item.id),
                      secondary: SizedBox(
                          width: 54,
                          height: 62,
                          child: photo(item.image, fit: BoxFit.contain)),
                      title: SmText(item.category),
                      onChanged: saving
                          ? null
                          : (value) => setState(() {
                                if (value!) {
                                  selected.add(item.id);
                                } else {
                                  selected.remove(item.id);
                                }
                              }))),
          ])),
          if (error != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: SmText(error!,
                    style: const TextStyle(color: Colors.orangeAccent))),
          Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      key: const Key('save-look'),
                      onPressed: saving
                          ? null
                          : () async {
                              setState(() => saving = true);
                              try {
                                await widget.store.saveLook(selected.toList(),
                                    occasion: occasion, style: style);
                                if (context.mounted) Navigator.pop(context);
                              } catch (_) {
                                if (mounted)
                                  setState(() {
                                    saving = false;
                                    error =
                                        'Kombin için üst ve alt giyim ya da elbise seçmelisin.';
                                  });
                              }
                            },
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const SmText('Kombini kaydet')))),
        ])),
      ));
}
