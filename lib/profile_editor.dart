import 'package:material_ui/material_ui.dart';
import 'closet.dart';
import 'localization.dart';
import 'main.dart' show SmText, LocalStrings;

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, required this.store});
  final ClosetStore store;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final fields = {
    for (final key in ['name', 'height', 'weight'])
      key: TextEditingController(text: widget.store.profile[key] ?? '')
  };
  late String tone = widget.store.profile['tone'] ?? 'medium';
  late String shape = widget.store.profile['shape'] ?? 'straight';
  late String size = widget.store.profile['size'] ?? 'M';
  bool saving = false;
  String tr(String s) => translate(s, widget.store.language);
  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget field(String key, String label, {double? min, double? max}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          key: Key('profile-$key'),
          controller: fields[key],
          decoration: InputDecoration(labelText: tr(label)),
          keyboardType: min == null
              ? TextInputType.name
              : const TextInputType.numberWithOptions(decimal: true),
          maxLength: key == 'name' ? 80 : 6,
          validator: (text) {
            if (min == null || text == null || text.isEmpty) return null;
            final value = double.tryParse(text.replaceAll(',', '.'));
            return value == null || value < min || value > max!
                ? '$min–$max'
                : null;
          }));
  Widget choice(String label, String value, Map<String, String> options,
          ValueChanged<String> onChanged) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
              initialValue:
                  options.containsKey(value) ? value : options.keys.first,
              decoration: InputDecoration(labelText: tr(label)),
              items: [
                for (final x in options.entries)
                  DropdownMenuItem(value: x.key, child: SmText(x.value))
              ],
              onChanged: saving ? null : (x) => setState(() => onChanged(x!))));
  @override
  Widget build(BuildContext context) => LocalStrings(
      language: widget.store.language,
      child: Scaffold(
        appBar: AppBar(title: const SmText('Stil Profilim')),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    field('name', 'Adın'),
                    Row(children: [
                      Expanded(
                          child:
                              field('height', 'Boy (cm)', min: 80, max: 250)),
                      const SizedBox(width: 12),
                      Expanded(
                          child:
                              field('weight', 'Kilo (kg)', min: 20, max: 350))
                    ]),
                    choice(
                        'Ten rengi',
                        tone,
                        {'light': 'Açık', 'medium': 'Orta', 'deep': 'Koyu'},
                        (x) => tone = x),
                    choice(
                        'Vücut tipi',
                        shape,
                        {
                          'straight': 'Dikdörtgen',
                          'curved': 'Kum saati',
                          'pear': 'Armut',
                          'oval': 'Oval',
                          'triangle': 'Ters üçgen'
                        },
                        (x) => shape = x),
                    choice(
                        'Beden',
                        size,
                        {
                          for (final x in [
                            'XS',
                            'S',
                            'M',
                            'L',
                            'XL',
                            'XXL',
                            '3XL',
                            '4XL'
                          ])
                            x: x
                        },
                        (x) => size = x),
                    const SmText(
                        'Bu profili kaydettiğinde hazır manken görünümün ten rengine, vücut tipine ve ölçülerine göre güncellenir.'),
                  ]))),
          Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      key: const Key('save-profile'),
                      onPressed: saving
                          ? null
                          : () async {
                              if (!form.currentState!.validate()) return;
                              setState(() => saving = true);
                              try {
                                await widget.store.updateProfile({
                                  for (final x in fields.entries)
                                    x.key: x.value.text.trim(),
                                  'tone': tone,
                                  'shape': shape,
                                  'size': size
                                });
                                if (context.mounted) Navigator.pop(context);
                              } catch (_) {
                                if (mounted) {
                                  setState(() => saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(tr('Kaydedilemedi.'))));
                                }
                              }
                            },
                      icon: const Icon(Icons.check),
                      label: const SmText('Kaydet'))))
        ])),
      ));
}
