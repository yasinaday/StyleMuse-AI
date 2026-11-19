import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'closet.dart';
import 'stylemuse_api.dart';
import 'model_images.dart';
import 'main.dart' show LocalStrings, SmText, photo;
import 'processing_photo.dart';
import 'localization.dart';

class MannequinPage extends StatefulWidget {
  const MannequinPage(
      {super.key,
      required this.store,
      required this.workflow,
      required this.confirmTokens,
      required this.pickPhoto,
      required this.onBusy,
      this.initialItems,
      this.occasion = 'Günlük',
      this.style = 'Rahat ve şık',
      this.onOpenWardrobe});
  final List<String>? initialItems;
  final String occasion, style;
  final ClosetStore store;
  final TokenWorkflowController workflow;
  final TokenConfirmation confirmTokens;
  final Future<Uint8List?> Function() pickPhoto;
  final ValueChanged<bool> onBusy;
  final VoidCallback? onOpenWardrobe;
  @override
  State<MannequinPage> createState() => _MannequinPageState();
}

class _MannequinPageState extends State<MannequinPage>
    with WidgetsBindingObserver {
  static const runKey = 'stylemuse.tryon.run';
  String? runOwner;
  bool restoring = false;
  bool automaticRecovery = false;
  Future<void> checkpoint() async {
    if (runOwner == null) return;
    await widget.workflow.storage.write(
        runKey,
        jsonEncode({
          'owner': runOwner,
          'selected': selected,
          'applied': applied,
          'remaining': remaining.map((i) => i.id).toList(),
          'active': activeGarment?.id,
          'image': attributedImage,
          'runningInput': runningInput,
          'completedInput': completedInput,
          'cancelled': cancelled,
        }));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final item in widget.store.items) {
      if (widget.initialItems?.contains(item.id) == true)
        selected[item.category] = item.id;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => restoreRun());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreRun());
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  Future<void> restoreRun() async {
    if (restoring || busy || !mounted) return;
    restoring = true;
    try {
      final saved = await widget.workflow.storage.read(runKey);
      if (saved == null || !mounted) return;
      final run = Map<String, dynamic>.from(jsonDecode(saved));
      final user = (await widget.workflow.api.account())['user'];
      if (user is! Map || run['owner'] != 'google:${user['id']}') return;
      runOwner = run['owner'] as String;
      selected
        ..clear()
        ..addAll(Map<String, String>.from(run['selected'] as Map));
      applied
        ..clear()
        ..addAll(Map<String, String>.from(run['applied'] as Map));
      remaining
        ..clear()
        ..addAll((run['remaining'] as List)
            .map((id) => widget.store.items.firstWhere((i) => i.id == id)));
      activeGarment = run['active'] == null
          ? null
          : widget.store.items.firstWhere((i) => i.id == run['active']);
      attributedImage = run['image'] as String?;
      runningInput = run['runningInput'] as String?;
      completedInput = run['completedInput'] as String?;
      cancelled = run['cancelled'] == true;
      if (widget.initialItems != null &&
          widget.initialItems!
              .toSet()
              .difference(selected.values.toSet())
              .isNotEmpty) {
        selected.clear();
        for (final item in widget.store.items) {
          if (widget.initialItems!.contains(item.id))
            selected[item.category] = item.id;
        }
        invalidateResult();
      }
      final pending = await widget.workflow.storage
          .read(TokenWorkflowController.pendingKey);
      if (pending != null &&
          (jsonDecode(pending) as Map)['action'] == 'tryon') {
        automaticRecovery = true;
        setBusy(true);
        await consume(await widget.workflow.recover());
      } else if (remaining.isNotEmpty) {
        status = 'Yarım kalan kombin · Seçimleri giydir ile devam et.';
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted)
        setState(() =>
            status = 'İşlem tamamlanamadı. Kurtar düğmesiyle kontrol et.');
    } finally {
      automaticRecovery = false;
      restoring = false;
      if (mounted && timer?.isActive != true) setBusy(false);
    }
  }

  final selected = <String, String>{};
  final remaining = <ClosetItem>[];
  // Provenance belongs to the rendered image, not the current selection.
  final applied = <String, String>{};
  String? attributedImage;
  ClosetItem? activeGarment;
  bool cancelled = false;
  String? completedInput;
  String? runningInput;
  void invalidateResult() {
    completedInput = null;
  }

  String inputSignature() => jsonEncode([
        widget.store.profile,
        for (final item in chosenItems) [item.id, item.category, item.image],
      ]);
  bool get completeSelection =>
      selected.containsKey('Elbise') ||
      (selected.containsKey('Üst giyim') && selected.containsKey('Alt giyim'));
  bool get canSave =>
      !busy &&
      !cancelled &&
      completeSelection &&
      completedInput == inputSignature() &&
      attributedImage != null &&
      attributedImage == widget.store.tryonResult;

  List<ClosetItem> get chosenItems {
    const order = [
      'Üst giyim',
      'Elbise',
      'Alt giyim',
      'Dış giyim',
      'Çanta',
      'Aksesuar',
      'Diğer'
    ];
    final items = [
      for (final id in selected.values)
        ...widget.store.items.where((item) => item.id == id)
    ];
    items.sort((a, b) =>
        order.indexOf(a.category).compareTo(order.indexOf(b.category)));
    return items;
  }

  int suggestion = 0;
  void suggest() {
    invalidateResult();
    selected.clear();
    final hasPair =
        widget.store.items.any((item) => item.category == 'Üst giyim') &&
            widget.store.items.any((item) => item.category == 'Alt giyim');
    final hasDress =
        widget.store.items.any((item) => item.category == 'Elbise');
    if (!hasPair && !hasDress) {
      suggestion++;
      return;
    }
    for (final category in wardrobeCategories) {
      final candidates = widget.store.items
          .where((item) => item.category == category)
          .toList();
      if (candidates.isEmpty) continue;
      if (category == 'Elbise' && hasPair) continue;
      if ((category == 'Üst giyim' || category == 'Alt giyim') &&
          !hasPair &&
          hasDress) continue;
      selected[category] = candidates[suggestion % candidates.length].id;
    }
    suggestion++;
  }

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
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  String get base =>
      widget.store.tryonResult ??
      (widget.store.profile['modelPhoto']?.isNotEmpty == true
          ? widget.store.profile['modelPhoto']!
          : mannequinAsset(widget.store.profile));
  Future<void> consume(Map<String, dynamic>? result) async {
    if (result == null) {
      if (activeGarment != null) remaining.insert(0, activeGarment!);
      activeGarment = null;
      await checkpoint();
      return;
    }
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
      remaining.clear();
      await widget.workflow.acknowledge();
      throw const StyleMuseApiException('tryon_failed');
    }
    final image = await loadTryOnImage(result['image']);
    if (!mounted) return;
    if (runningInput != inputSignature()) {
      await widget.store.saveTryOn(image);
      attributedImage = image;
      remaining.clear();
      activeGarment = null;
      completedInput = null;
      await checkpoint();
      await widget.workflow.acknowledge();
      return;
    }
    final previousImage = widget.store.tryonResult;
    await widget.store.saveTryOn(image);
    if (attributedImage != previousImage) applied.clear();
    final item = activeGarment;
    if (item != null) {
      if (item.category == 'Elbise') {
        applied.remove('Üst giyim');
        applied.remove('Alt giyim');
      } else if (item.category == 'Üst giyim' || item.category == 'Alt giyim') {
        applied.remove('Elbise');
      }
      applied[item.category] = item.id;
    }
    attributedImage = image;
    activeGarment = null;
    if (item != null &&
        remaining.isEmpty &&
        selected.length == applied.length &&
        selected.entries.every((entry) => applied[entry.key] == entry.value)) {
      completedInput = runningInput;
    }
    await checkpoint();
    await widget.workflow.acknowledge();
    if (mounted && !cancelled && !automaticRecovery && remaining.isNotEmpty) {
      await nextGarment();
      return;
    }
    if (item != null &&
        remaining.isEmpty &&
        selected.length == applied.length &&
        selected.entries.every((entry) => applied[entry.key] == entry.value)) {
      completedInput = runningInput;
    }
    if (mounted)
      setState(() =>
          status = 'Kurtarılan görseli Kombinler bölümüne kaydedebilirsin.');
  }

  Future<void> poll() async {
    automaticRecovery = true;
    try {
      await consume(await widget.workflow.recover());
    } catch (_) {
      if (mounted)
        setState(() => status = widget.workflow.pending == null
            ? 'İşlem tamamlanamadı. Google girişini ve bağlantını kontrol et.'
            : 'İşlem tamamlanamadı. Kurtar düğmesiyle kontrol et.');
    } finally {
      automaticRecovery = false;
      if (mounted && timer?.isActive != true) setBusy(false);
    }
  }

  Future<void> start() async {
    if (selected.isEmpty || busy) return;
    setBusy(true);
    try {
      final user = (await widget.workflow.api.account())['user'];
      if (user is! Map || user['provider'] != 'google' || user['id'] is! String)
        throw const StyleMuseApiException('sign_in_required');
      runOwner = 'google:${user['id']}';
      final pending = await widget.workflow.storage
          .read(TokenWorkflowController.pendingKey);
      if (pending != null) {
        automaticRecovery = true;
        await consume(await widget.workflow.recover());
        return;
      }
      final continuing = !cancelled &&
          runningInput == inputSignature() &&
          remaining.isNotEmpty &&
          activeGarment == null;
      cancelled = false;
      if (!continuing) {
        completedInput = null;
        runningInput = inputSignature();
        applied.clear();
        attributedImage = null;
        await widget.store.saveTryOn(null);
        remaining
          ..clear()
          ..addAll(chosenItems);
      }
      await checkpoint();
      await nextGarment();
    } catch (_) {
      if (mounted)
        setState(() => status = widget.workflow.pending == null
            ? 'İşlem tamamlanamadı. Google girişini ve bağlantını kontrol et.'
            : 'İşlem tamamlanamadı. Kurtar düğmesiyle kontrol et.');
    } finally {
      automaticRecovery = false;
      if (mounted && timer?.isActive != true) setBusy(false);
    }
  }

  Future<void> nextGarment() async {
    if (cancelled || !mounted || remaining.isEmpty) return;
    final item = remaining.removeAt(0);
    final person = await jpegData(base);
    final garment = await jpegData(item.image);
    if (cancelled || !mounted) return;
    activeGarment = item;
    await checkpoint();
    await consume(await widget.workflow
        .tryOn(person, garment, confirm: widget.confirmTokens));
  }

  Future<void> ownPhoto() async {
    try {
      final bytes = await widget.pickPhoto();
      if (bytes == null) return;
      invalidateResult();
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
    final chosen = chosenItems;
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
                                                            BorderRadius
                                                                .circular(10)),
                                                    child: i < chosen.length
                                                        ? photo(chosen[i].image,
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
                                                  onPressed: busy ||
                                                          widget.store.items
                                                              .isEmpty
                                                      ? null
                                                      : () => setState(suggest),
                                                  child: const SmText('KOMBİN\nÖNER',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w800)))),
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
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10))),
                                                  onPressed: busy
                                                      ? null
                                                      : () => setState(() {
                                                            invalidateResult();
                                                            selected.clear();
                                                          }),
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
                                              child: ProcessingPhoto(
                                                  active: busy,
                                                  stage: tr(
                                                      'Giydirme devam ediyor…'),
                                                  child: photo(base,
                                                      fit: BoxFit.contain)))),
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
                                                  : chosen.isEmpty
                                                      ? 'Kombinin için kıyafet seç.'
                                                      : chosen
                                                          .map((item) =>
                                                              item.category)
                                                          .join(' · '),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                    ])),
                          ]))),
              const SizedBox(height: 6),
              if (suggestion > 0)
                Wrap(
                  key: const Key('outfit-recommendations'),
                  spacing: 6,
                  children: [
                    for (var i = 0; i < widget.store.items.length; i++)
                      FilterChip(
                        key: Key('recommendation-$i'),
                        label: SmText(widget.store.items[i].category),
                        selected: selected[widget.store.items[i].category] ==
                            widget.store.items[i].id,
                        onSelected: busy
                            ? null
                            : (_) => setState(() {
                                  invalidateResult();
                                  final item = widget.store.items[i];
                                  if (selected[item.category] == item.id) {
                                    selected.remove(item.category);
                                  } else {
                                    if (item.category == 'Elbise') {
                                      selected.remove('Üst giyim');
                                      selected.remove('Alt giyim');
                                    } else if (item.category == 'Üst giyim' ||
                                        item.category == 'Alt giyim') {
                                      selected.remove('Elbise');
                                    }
                                    selected[item.category] = item.id;
                                  }
                                }),
                      ),
                  ],
                ),
              OutlinedButton.icon(
                  key: const Key('save-tryon'),
                  onPressed: !canSave
                      ? null
                      : () async {
                          try {
                            if (!canSave) return;
                            await widget.store.saveLook(applied.values.toList(),
                                occasion: widget.occasion,
                                style: widget.style,
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
                  onPressed: busy || selected.isEmpty ? null : start,
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
                            invalidateResult();
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
                                    : () => setState(() {
                                          invalidateResult();
                                          if (selected[item.category] ==
                                              item.id) {
                                            selected.remove(item.category);
                                          } else {
                                            if (item.category == 'Elbise') {
                                              selected.remove('Üst giyim');
                                              selected.remove('Alt giyim');
                                            } else if (item.category ==
                                                    'Üst giyim' ||
                                                item.category == 'Alt giyim') {
                                              selected.remove('Elbise');
                                            }
                                            selected[item.category] = item.id;
                                          }
                                        }),
                                child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        border: Border.all(
                                            color: selected[item.category] ==
                                                    item.id
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
              if (status.isNotEmpty || widget.workflow.pending != null)
                Card(
                    color: const Color(0xFFF3DDF0),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(
                              child: SmText(status.isEmpty
                                  ? 'Yarım kalan işlem'
                                  : status)),
                          if (widget.workflow.pending != null)
                            TextButton(
                                key: const Key('recover-tryon'),
                                onPressed: busy ? null : restoreRun,
                                child: const SmText('Kurtar')),
                        ]))),
              if (busy)
                TextButton(
                    onPressed: () {
                      timer?.cancel();
                      cancelled = true;
                      widget.workflow.cancel();
                      checkpoint();
                      setBusy(false);
                      setState(() => status =
                          'İşlem cihazda durduruldu. Kullanılan jetonlar geri yüklenmez; sonucu Kurtar ile kontrol et.');
                    },
                    child: const SmText('İptal et')),
            ]));
  }
}
