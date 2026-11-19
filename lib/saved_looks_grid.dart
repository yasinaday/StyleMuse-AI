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

  Future<void> share(Map<String, dynamic> look) async {
    final aiImage = look['aiImage'];
    final images = aiImage is String
        ? [aiImage]
        : List<String>.from(look['images'] as List? ?? []);
    final files = <XFile>[];
    for (final image in images) {
      if (!safeImage(image)) continue;
      final mime = image.substring(5, image.indexOf(';'));
      final extension = mime.split('/').last;
      files.add(XFile.fromData(base64Decode(image.split(',').last),
          mimeType: mime, name: 'stylemuse-${files.length + 1}.$extension'));
    }
    final text = 'StyleMuse · ${look['occasion'] ?? tr('Günlük')}';
    if (files.isNotEmpty) {
      await Share.shareXFiles(files, text: text);
    } else {
      final links =
          images.where((image) => !safeImage(image) && safeOutfitPhoto(image));
      await Share.share([text, ...links].join('\n'));
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
    // Locate the original object again after the confirmation; an import may
    // have replaced the list while the dialog was open.
    final index =
        widget.store.looks.indexWhere((entry) => identical(entry, look));
    if (index >= 0) await widget.store.deleteLook(index);
  }

  @override
  Widget build(BuildContext context) => LocalStrings(
      language: widget.store.language,
      child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => Column(children: [
                if (error != null) SmText(error!),
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
                    itemCount: widget.store.looks.length,
                    itemBuilder: (context, index) {
                      final look = widget.store.looks[index];
                      final images =
                          List<String>.from(look['images'] as List? ?? []);
                      final aiImage = look['aiImage'];
                      return Card(
                          key: Key('saved-look-$index'),
                          child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                        child: aiImage is String
                                            ? photo(aiImage,
                                                fit: BoxFit.contain)
                                            : GridView.count(
                                                crossAxisCount: 2,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                children: [
                                                    for (final image
                                                        in images.take(4))
                                                      photo(image,
                                                          fit: BoxFit.contain)
                                                  ])),
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
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          IconButton(
                                              key: Key('share-look-$index'),
                                              tooltip: tr('Paylaş'),
                                              onPressed: busy
                                                  ? null
                                                  : () => run(() =>
                                                      widget.shareLook
                                                          ?.call(look) ??
                                                      share(look)),
                                              icon: const Icon(Icons.ios_share,
                                                  size: 20)),
                                          IconButton(
                                              key: Key('delete-look-$index'),
                                              tooltip: tr('Sil'),
                                              onPressed: busy
                                                  ? null
                                                  : () =>
                                                      run(() => delete(look)),
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 20)),
                                        ]),
                                  ])));
                    }),
              ])));
}
