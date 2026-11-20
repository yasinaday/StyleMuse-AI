import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'closet.dart';
import 'localization.dart';
import 'main.dart' show LocalStrings, SmText, photo;

class SavedLooksGrid extends StatefulWidget {
  const SavedLooksGrid({super.key, required this.store, this.shareLook});
  final ClosetStore store;
  final Future<void> Function(Map<String, dynamic>)? shareLook;
  @override
  State<SavedLooksGrid> createState() => _SavedLooksGridState();
}

class _SavedLooksGridState extends State<SavedLooksGrid> {
  bool busy = false;
  String? error;
  String tr(String value) => translate(value, widget.store.language);

  DateTime? savedAt(Map<String, dynamic> look) {
    final value = look['date']?.toString() ?? '';
    final parts = value.split('.');
    if (parts.length == 3 && parts.every((part) => int.tryParse(part) != null)) {
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    }
    return DateTime.tryParse(value);
  }

  Future<void> share(Map<String, dynamic> look) async {
    final image = look['aiImage'];
    if (!safeOutfitPhoto(image)) return;
    final source = image as String;
    final text = 'StyleMuse · ${look['occasion'] ?? tr('Günlük')}';
    if (safeImage(source)) {
      final mime = source.substring(5, source.indexOf(';'));
      final extension = mime.split('/').last;
      await Share.shareXFiles([
        XFile.fromData(base64Decode(source.split(',').last),
            mimeType: mime, name: 'stylemuse.$extension'),
      ], text: text);
    } else {
      await Share.share('$text\n$source');
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted)
        setState(() => error =
            'İşlem tamamlanamadı. Dosyayı ve depolama alanını kontrol et.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete(Map<String, dynamic> look) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) =>
            AlertDialog(content: Text(tr('Bu kombin silinsin mi?')), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(tr('Vazgeç'))),
              FilledButton(
                  key: const Key('confirm-delete-look'),
                  onPressed: () => Navigator.pop(dialog, true),
                  child: Text(tr('Sil'))),
            ]));
    if (confirmed != true || !mounted) return;
    await widget.store.deleteLookEntry(look);
  }

  @override
  Widget build(BuildContext context) => LocalStrings(
      language: widget.store.language,
      child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final entries = widget.store.looks.asMap().entries
                .where((entry) => safeOutfitPhoto(entry.value['aiImage']))
                .toList()
              ..sort((a, b) {
                final first = savedAt(a.value);
                final second = savedAt(b.value);
                if (first == null && second != null) return 1;
                if (second == null && first != null) return -1;
                final order = second?.compareTo(first!) ?? 0;
                return order == 0 ? b.key.compareTo(a.key) : order;
              });
            return Column(children: [
              if (error != null) SmText(error!),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: SmText('Henüz kayıtlı kombin yok.',
                      style: TextStyle(color: Color(0xFF8A7886), fontSize: 13)),
                )
              else
                GridView.builder(
                    key: const Key('saved-looks-grid'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 280),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final look = entries[index].value;
                      return Card(
                          key: Key('saved-look-$index'),
                          child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                        child: photo(look['aiImage'] as String,
                                            fit: BoxFit.contain)),
                                    Text(
                                        tr(look['occasion'] as String? ??
                                            'Günlük'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        (look['date'] as String? ?? '')
                                            .split('T')
                                            .first,
                                        style: const TextStyle(fontSize: 11)),
                                    Wrap(
                                        alignment: WrapAlignment.spaceEvenly,
                                        children: [
                                          TextButton.icon(
                                              key: Key('share-look-$index'),
                                              label: Text(tr('Paylaş'), style: const TextStyle(fontSize: 12)),
                                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 5), foregroundColor: const Color(0xFF695A68)),
                                              onPressed: busy
                                                  ? null
                                                  : () => run(() =>
                                                      widget.shareLook
                                                          ?.call(look) ??
                                                      share(look)),
                                              icon: const Icon(Icons.ios_share,
                                                  size: 16)),
                                          TextButton.icon(
                                              key: Key('delete-look-$index'),
                                              label: Text(tr('Sil'), style: const TextStyle(fontSize: 12)),
                                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 5), foregroundColor: const Color(0xFF695A68)),
                                              onPressed: busy
                                                  ? null
                                                  : () =>
                                                      run(() => delete(look)),
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 16)),
                                        ]),
                                  ])));
                    }),
            ]);
          }));
}
