import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'closet.dart';
import 'stylemuse_api.dart';
import 'model_images.dart';
import 'main.dart' show LocalStrings, SmText, photo;
import 'localization.dart';

class MannequinPage extends StatefulWidget {
  const MannequinPage(
      {super.key,
      required this.store,
      required this.workflow,
      required this.confirmTokens,
      required this.pickPhoto,
      required this.onBusy,
      this.onOpenWardrobe});
  final ClosetStore store;
  final TokenWorkflowController workflow;
  final TokenConfirmation confirmTokens;
  final Future<Uint8List?> Function() pickPhoto;
  final ValueChanged<bool> onBusy;
  final VoidCallback? onOpenWardrobe;
  @override
  State<MannequinPage> createState() => _MannequinPageState();
}

class _MannequinPageState extends State<MannequinPage> {
  String? selected;
  bool busy = false;
  String status = '';
  Timer? timer;
  String tr(String s) => translate(s, widget.store.language);
  void setBusy(bool value) {
    if (mounted) {
      setState(() => busy = value);
      widget.onBusy(value);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String get base =>
      widget.store.tryonResult ??
      (widget.store.profile['modelPhoto']?.isNotEmpty == true
          ? widget.store.profile['modelPhoto']!
          : mannequinAsset(widget.store.profile));
  Future<void> consume(Map<String, dynamic>? result) async {
    if (result == null) return;
    if (result['state'] == 'pending' ||
        result['state'] == 'running' ||
        result['state'] == 'processing') {
      if (mounted) {
        setState(() => status = 'Giydirme devam ediyor…');
        timer = Timer(const Duration(seconds: 3), poll);
      }
      return;
    }
    if (result['state'] == 'failed') {
      await widget.workflow.acknowledge();
      throw const StyleMuseApiException('tryon_failed');
    }
    final image = await loadTryOnImage(result['image']);
    await widget.store.saveTryOn(image);
    await widget.workflow.acknowledge();
    if (mounted)
      setState(() =>
          status = 'Kurtarılan görseli Kombinler bölümüne kaydedebilirsin.');
  }

  Future<void> poll() async {
    try {
      await consume(await widget.workflow.recover());
    } catch (_) {
      if (mounted)
        setState(() => status = widget.workflow.pending == null
            ? 'İşlem tamamlanamadı. Google girişini ve bağlantını kontrol et.'
            : 'İşlem tamamlanamadı. Kurtar düğmesiyle kontrol et.');
    } finally {
      if (mounted && timer?.isActive != true) setBusy(false);
    }
  }

  Future<void> start() async {
    if (selected == null || busy) return;
    final item = widget.store.items.where((x) => x.id == selected).firstOrNull;
    if (item == null) return;
    setBusy(true);
    try {
      final person = await jpegData(base);
      final garment = await jpegData(item.image);
      await consume(await widget.workflow
          .tryOn(person, garment, confirm: widget.confirmTokens));
    } catch (_) {
      if (mounted)
        setState(() => status = widget.workflow.pending == null
            ? 'İşlem tamamlanamadı. Google girişini ve bağlantını kontrol et.'
            : 'İşlem tamamlanamadı. Kurtar düğmesiyle kontrol et.');
    } finally {
      if (mounted && timer?.isActive != true) setBusy(false);
    }
  }

  Future<void> ownPhoto() async {
    try {
      final bytes = await widget.pickPhoto();
      if (bytes == null) return;
      final image =
          await jpegData('data:image/jpeg;base64,${base64Encode(bytes)}');
      await widget.store.updateProfile({'modelPhoto': image});
      await widget.store.saveTryOn(null);
      if (mounted)
        setState(() => status =
            'Fotoğraf hazır. Her giydirme adımı için 1 Stil Jetonu kullanılır.');
    } catch (_) {
      if (mounted) setState(() => status = 'Fotoğraf açılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen =
        widget.store.items.where((item) => item.id == selected).firstOrNull;
    return LocalStrings(
        language: widget.store.language,
        child: ListView(
            key: const Key('mannequin-page'),
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
            children: [
              Container(
                  height: 105,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: const LinearGradient(
                          colors: [Color(0xFF492448), Color(0xFF9B6095)])),
                  child: Row(children: [
                    const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: SmText('Mankenim',
                                  style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.white))),
                          SizedBox(height: 8),
                          Flexible(
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.topLeft,
                                  child: SizedBox(
                                      width: 180,
                                      child: SmText(
                                          'Dolabından seç, manken üzerinde dene.',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white)))))
                        ])),
                    const SizedBox(width: 10),
                    Image.asset('assets/home/tryon.webp',
                        width: 140, fit: BoxFit.contain),
                  ])),
              const SizedBox(height: 13),
              // The reference stage is 32% selected items / 68% full-body photo.
              // A fixed aspect ratio keeps selection from changing or cropping the model.
              AspectRatio(
                  aspectRatio: .77,
                  child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF8F0F6),
                          borderRadius: BorderRadius.circular(22)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                                flex: 32,
                                child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(8, 8, 5, 6),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (var i = 0; i < 4; i++) ...[
                                            if (i > 0)
                                              const SizedBox(height: 5),
                                            Expanded(
                                                child: Container(
                                                    key: Key(
                                                        'mannequin-slot-$i'),
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFFFBF3FA),
                                                        border: Border.all(
                                                            color: const Color(
                                                                0xFFE9DCE6)),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                10)),
                                                    child: i == 0 &&
                                                            chosen != null
                                                        ? photo(chosen.image,
                                                            fit: BoxFit.contain)
                                                        : const SizedBox
                                                            .expand())),
                                          ],
                                          const SizedBox(height: 7),
                                          SizedBox(
                                              height: 44,
                                              child: FilledButton.tonal(
                                                  key: const Key(
                                                      'mannequin-suggest'),
                                                  style: FilledButton.styleFrom(
                                                      padding: EdgeInsets.zero,
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  11))),
                                                  onPressed:
                                                      busy || widget.store.items.isEmpty
                                                          ? null
                                                          : () => setState(() =>
                                                              selected = widget
                                                                  .store
                                                                  .items
                                                                  .first
                                                                  .id),
                                                  child: const SmText('KOMBİN\nÖNER',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)))),
                                          const SizedBox(height: 2),
                                          SizedBox(
                                              height: 30,
                                              child: TextButton(
                                                  key: const Key(
                                                      'mannequin-clear'),
                                                  style: TextButton.styleFrom(
                                                      padding: EdgeInsets.zero,
                                                      backgroundColor:
                                                          const Color(
                                                              0xFFFFF9FD),
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  10))),
                                                  onPressed: busy
                                                      ? null
                                                      : () => setState(() =>
                                                          selected = null),
                                                  child: const SmText('Temizle',
                                                      style: TextStyle(
                                                          fontSize: 12)))),
                                        ]))),
                            Expanded(
                                flex: 68,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                          child: SizedBox(
                                              key: const Key(
                                                  'mannequin-preview'),
                                              child: photo(base,
                                                  fit: BoxFit.contain))),
                                      Container(
                                          height: 30,
                                          margin: const EdgeInsets.fromLTRB(
                                              3, 0, 3, 6),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFFFF9FD),
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: SmText(
                                              busy
                                                  ? 'Giydirme devam ediyor…'
                                                  : chosen == null
                                                      ? 'Kombinin için kıyafet seç.'
                                                      : chosen.category,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                    ])),
                          ]))),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                  key: const Key('save-tryon'),
                  onPressed: busy ||
                          (selected == null && widget.store.tryonResult == null)
                      ? null
                      : () async {
                          try {
                            await widget.store.saveLook(
                                selected == null ? [] : [selected!],
                                aiImage: widget.store.tryonResult);
                            if (mounted)
                              setState(() => status = 'Kombin kaydedildi.');
                          } catch (_) {
                            if (mounted)
                              setState(() => status = 'Kaydedilemedi.');
                          }
                        },
                  icon: const Icon(Icons.favorite_border, size: 18),
                  label: const SmText('Kombinimi kaydet')),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                  onPressed: busy ? null : ownPhoto,
                  icon: const Icon(Icons.add, size: 18),
                  label: const SmText('Kendi fotoğrafımı yükle')),
              const SizedBox(height: 6),
              FilledButton.icon(
                  key: const Key('tryon-start'),
                  onPressed: busy || selected == null ? null : start,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const SmText('Yapay zekâ ile gerçekçi giydir')),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(
                    child: SmText('Dolabımdan seç',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(
                    tooltip: tr('Sıfırla'),
                    onPressed: busy
                        ? null
                        : () async {
                            await widget.store
                                .updateProfile({'modelPhoto': ''});
                            await widget.store.saveTryOn(null);
                            if (mounted) setState(() {});
                          },
                    icon: const Icon(Icons.refresh))
              ]),
              if (widget.store.items.isEmpty) ...[
                const SmText(
                    'Dolabın henüz boş. İlk kıyafetini ekleyerek başla.'),
                OutlinedButton.icon(
                    key: const Key('mannequin-add-clothes'),
                    onPressed: busy ? null : widget.onOpenWardrobe,
                    icon: const Icon(Icons.add),
                    label: const SmText('Kıyafet ekle')),
              ],
              SizedBox(
                  height: 105,
                  child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.store.items.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final item = widget.store.items[i];
                        return SizedBox(
                            width: 88,
                            child: InkWell(
                                key: Key('try-garment-$i'),
                                onTap: busy
                                    ? null
                                    : () => setState(() => selected =
                                        selected == item.id ? null : item.id),
                                child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        border: Border.all(
                                            color: selected == item.id
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : const Color(0xFFE9DCE6),
                                            width: 2),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Column(children: [
                                      Expanded(
                                          child: photo(item.image,
                                              fit: BoxFit.contain)),
                                      SmText(item.category,
                                          style: const TextStyle(fontSize: 11))
                                    ]))));
                      })),
              const SizedBox(height: 12),
              const SmText(
                  'Fotoğraf hazır. Her giydirme adımı için 1 Stil Jetonu kullanılır.'),
              if (status.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SmText(status)),
              if (busy)
                TextButton(
                    onPressed: () {
                      timer?.cancel();
                      widget.workflow.cancel();
                      setBusy(false);
                      setState(() => status =
                          'İşlem cihazda durduruldu. Kullanılan jetonlar geri yüklenmez; sonucu Kurtar ile kontrol et.');
                    },
                    child: const SmText('İptal et')),
            ]));
  }
}
