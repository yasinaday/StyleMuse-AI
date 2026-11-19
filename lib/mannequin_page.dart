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
  String? sequenceId;
  String? sequenceState;
  List<String> sequenceItems = [];
  bool get hasSequence =>
      sequenceId != null && !['done', 'failed'].contains(sequenceState);
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
          'sequenceId': sequenceId,
          'sequenceState': sequenceState,
          'sequenceItems': sequenceItems,
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
      if (!mounted ||
          user is! Map ||
          user['provider'] != 'google' ||
          run['owner'] != 'google:${user['id']}') return;
      runOwner = run['owner'] as String;
      sequenceId = run['sequenceId'] as String?;
      sequenceState = run['sequenceState'] as String?;
      sequenceItems = List<String>.from(run['sequenceItems'] as List? ?? []);
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
      if (!hasSequence &&
          widget.initialItems != null &&
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
      if (hasSequence) {
        cancelled = false;
        setBusy(true);
        await driveSequence(advance: false);
      } else if (pending != null &&
          (jsonDecode(pending) as Map)['action'] == 'tryon') {
        setBusy(true);
        await consume(await widget.workflow.recover());
      } else if (sequenceId == null && remaining.isNotEmpty) {
        status = 'Yarım kalan kombin · Seçimleri giydir ile devam et.';
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted)
        setState(() =>
            status = 'İşlem tamamlanamadı. Kurtar düğmesiyle kontrol et.');
    } finally {
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
      !saving &&
      !isSaved &&
      !cancelled &&
      completeSelection &&
      completedInput == inputSignature() &&
      attributedImage != null &&
      attributedImage == widget.store.tryonResult;

  bool saving = false;
  bool get isSaved =>
      attributedImage != null &&
      widget.store.looks.any((look) => look['aiImage'] == attributedImage);

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

  String get base => widget.store.tryonResult ?? sourceImage;
  String get sourceImage =>
      (widget.store.profile['modelPhoto']?.isNotEmpty == true
          ? widget.store.profile['modelPhoto']!
          : studioAsset(widget.store.profile['studioMannequin']) ??
              mannequinAsset(widget.store.profile));

  String? studioAsset(String? id) =>
      List.generate(10, (i) => '${i + 1}').contains(id)
          ? 'assets/mannequins/studio-$id.webp'
          : null;

  Future<void> selectModel() async {
    final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => GridView.count(
              padding: const EdgeInsets.all(12),
              crossAxisCount: 3,
              children: [
                for (final id in [
                  'profile',
                  ...List.generate(10, (i) => '${i + 1}')
                ])
                  InkWell(
                    key: Key('mannequin-model-$id'),
                    onTap: () => Navigator.pop(context, id),
                    child: Column(children: [
                      Expanded(
                          child: photo(
                              studioAsset(id) ??
                                  mannequinAsset(widget.store.profile),
                              fit: BoxFit.contain)),
                      SmText(id == 'profile' ? 'Profil mankeni' : 'Manken $id'),
                    ]),
                  ),
              ],
            ));
    if (choice == null || !mounted || busy || hasSequence) return;
    await widget.store
        .updateProfile({'modelPhoto': '', 'studioMannequin': choice});
    await widget.store.saveTryOn(null);
    if (mounted) setState(invalidateResult);
  }

  Future<void> driveSequence({required bool advance}) async {
    final key = {'request_id': sequenceId};
    final api = widget.workflow.api;
    Map<String, dynamic> result;
    while (mounted && !cancelled) {
      try {
        result = await api.post('/api/tryon/sequence/status', key);
      } on StyleMuseApiException catch (error) {
        if (error.code != 'sequence_not_found') rethrow;
        sequenceState = 'failed';
        await checkpoint();
        if (mounted)
          setState(
              () => status = 'Giydirme oturumu bulunamadı veya süresi doldu.');
        return;
      }
      if (!mounted || cancelled) return;
      final state = result['state'] as String;
      final completed = result['completed'] as int;
      if (completed < 0 ||
          completed > sequenceItems.length ||
          result['total'] != sequenceItems.length ||
          (state == 'done' && completed != sequenceItems.length)) {
        throw const StyleMuseApiException('invalid_sequence_status');
      }
      if (completed > 0 &&
          (completed != applied.length || attributedImage == null)) {
        final image = await loadTryOnImage(result['image']);
        if (!mounted || cancelled) return;
        await widget.store.saveTryOn(image);
        attributedImage = image;
        final ids = sequenceItems.take(completed).toSet();
        applied
          ..clear()
          ..addEntries(
              selected.entries.where((entry) => ids.contains(entry.value)));
      }
      sequenceState = state;
      if (state == 'done') completedInput = runningInput;
      await checkpoint();
      if (!mounted || cancelled) return;
      setState(() => status = switch (state) {
            'done' => 'Kombin hazır.',
            'ready' =>
              '$completed/${sequenceItems.length} · Devam etmeye hazır.',
            'pending' =>
              '$completed/${sequenceItems.length} · Giydirme devam ediyor…',
            'unresolved' ||
            'ambiguous' =>
              'Gönderim doğrulanamadı. Adım yeniden gönderilmez.',
            _ => 'Giydirme tamamlanamadı.',
          });
      if (state == 'ready' && advance) {
        await api
            .post('/api/tryon/sequence/advance', {...key, 'step': completed});
        continue;
      }
      if (state == 'pending') {
        timer = Timer(const Duration(seconds: 3), () => runSequence(advance));
      }
      return;
    }
  }

  Future<void> runSequence(bool advance) async {
    try {
      await driveSequence(advance: advance);
    } catch (_) {
      if (mounted)
        setState(() => status = 'İşlem kesildi. Kurtar ile durumu kontrol et.');
    } finally {
      if (mounted && timer?.isActive != true) setBusy(false);
    }
  }

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
    if (busy || restoring || (selected.isEmpty && !hasSequence)) return;
    setBusy(true);
    try {
      final user = (await widget.workflow.api.account())['user'];
      if (user is! Map || user['provider'] != 'google' || user['id'] is! String)
        throw const StyleMuseApiException('sign_in_required');
      final owner = 'google:${user['id']}';
      if (hasSequence) {
        if (runOwner != owner)
          throw const StyleMuseApiException('pending_account_mismatch');
        cancelled = false;
        await runSequence(true);
        return;
      }
      final pending = await widget.workflow.storage
          .read(TokenWorkflowController.pendingKey);
      if (pending != null) {
        await consume(await widget.workflow.recover());
        return;
      }
      cancelled = false;
      final items = chosenItems;
      if (items.isEmpty) return;
      final signature = inputSignature();
      final id = widget.workflow.requestId();
      final inputs = {
        'request_id': id,
        'person_image': await jpegData(sourceImage),
        'garments': [for (final item in items) await jpegData(item.image)],
        'garment_ids': [for (final item in items) item.id],
      };
      final api = widget.workflow.api;
      final quote = await api
          .post('/api/quote', {'action': 'tryon_sequence', 'inputs': inputs});
      if (quote['style_tokens'] != items.length ||
          quote['quote_id'] is! String ||
          quote['estimated_cost_usd'] is! num) {
        throw const StyleMuseApiException('token_quote_mismatch');
      }
      if (!mounted ||
          cancelled ||
          !await widget.confirmTokens(items.length) ||
          !mounted ||
          cancelled) return;
      runOwner = owner;
      sequenceId = id;
      sequenceState = 'starting';
      sequenceItems = items.map((item) => item.id).toList();
      completedInput = null;
      runningInput = signature;
      applied.clear();
      remaining.clear();
      activeGarment = null;
      attributedImage = null;
      await checkpoint();
      if (!mounted || cancelled) return;
      await widget.store.saveTryOn(null);
      await api.post('/api/tryon/sequence', {
        ...inputs,
        'quote_id': quote['quote_id'],
        'confirmed': true,
        'max_total_usd': quote['estimated_cost_usd'],
      });
      await runSequence(true);
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
      invalidateResult();
      final image =
          await jpegData('data:image/jpeg;base64,${base64Encode(bytes)}');
      await widget.store.updateProfile({'modelPhoto': image});
      await widget.store.saveTryOn(null);
      if (mounted) setState(() => status = 'Fotoğraf hazır.');
    } catch (_) {
      if (mounted) setState(() => status = 'Fotoğraf açılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = chosenItems;
    final locked = busy || restoring || hasSequence;
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
                                          for (var i = 0;
                                              i <
                                                  (chosen.length > 4
                                                      ? chosen.length
                                                      : 4);
                                              i++) ...[
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
                                                        ? Stack(
                                                            fit:
                                                                StackFit.expand,
                                                            children: [
                                                                photo(
                                                                    chosen[i]
                                                                        .image,
                                                                    fit: BoxFit
                                                                        .contain),
                                                                Positioned(
                                                                    top: 0,
                                                                    right: 0,
                                                                    child: SizedBox(
                                                                        width: 32,
                                                                        height: 32,
                                                                        child: IconButton(
                                                                            key: ValueKey('remove-selected-${chosen[i].id}'),
                                                                            tooltip: tr('Seçimden çıkar'),
                                                                            padding: EdgeInsets.zero,
                                                                            style: IconButton.styleFrom(backgroundColor: const Color(0xFFFFF9FD)),
                                                                            onPressed: locked
                                                                                ? null
                                                                                : () => setState(() {
                                                                                      invalidateResult();
                                                                                      selected.remove(chosen[i].category);
                                                                                    }),
                                                                            icon: const Icon(Icons.close, size: 18))))
                                                              ])
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
                                                  onPressed: locked ||
                                                          widget.store.items
                                                              .isEmpty
                                                      ? null
                                                      : () => setState(suggest),
                                                  child: const SmText(
                                                      'KOMBİN\nÖNER',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w800)))),
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
                                                  onPressed: locked
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
                                    ])),
                          ]))),
              const SizedBox(height: 6),
              if (sequenceId != null)
                Column(key: const Key('tryon-step-progress'), children: [
                  for (var i = 0; i < chosen.length; i++)
                    ListTile(
                        dense: true,
                        leading: Icon(
                            applied.containsValue(chosen[i].id)
                                ? Icons.check_circle
                                : i == applied.length
                                    ? Icons.hourglass_top
                                    : Icons.schedule,
                            color: const Color(0xFF904588)),
                        title: SmText(chosen[i].category),
                        subtitle: SmText(applied.containsValue(chosen[i].id)
                            ? 'Tamamlandı'
                            : i == applied.length
                                ? 'Şimdiki adım'
                                : 'Sıradaki adım')),
                ]),
              OutlinedButton.icon(
                  key: const Key('save-tryon'),
                  onPressed: !canSave
                      ? null
                      : () async {
                          try {
                            if (!canSave) return;
                            setState(() => saving = true);
                            await widget.store.saveLook(applied.values.toList(),
                                occasion: widget.occasion,
                                style: widget.style,
                                aiImage: widget.store.tryonResult);
                            if (mounted)
                              setState(() => status = 'Kombin kaydedildi.');
                          } catch (_) {
                            if (mounted)
                              setState(() => status = 'Kaydedilemedi.');
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                  icon: const Icon(Icons.favorite_border, size: 18),
                  label: SmText(isSaved
                      ? 'Kaydedildi'
                      : saving
                          ? 'Kaydediliyor…'
                          : 'Kombinimi kaydet')),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                  key: const Key('select-mannequin'),
                  onPressed: locked ? null : selectModel,
                  icon: const Icon(Icons.person_outline),
                  label: const SmText('Manken seç')),
              OutlinedButton.icon(
                  onPressed: locked ? null : ownPhoto,
                  icon: const Icon(Icons.add, size: 18),
                  label: const SmText('Kendi fotoğrafımı yükle')),
              const SizedBox(height: 6),
              FilledButton.icon(
                  key: const Key('tryon-start'),
                  onPressed:
                      busy || restoring || (selected.isEmpty && !hasSequence)
                          ? null
                          : start,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: SmText(hasSequence
                      ? 'Giydirmeye devam et'
                      : 'Yapay zekâ ile gerçekçi giydir')),
              const SizedBox(height: 14),
              const SmText('Dolabımdan seç',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                onTap: locked
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
              if (status.isNotEmpty ||
                  hasSequence ||
                  widget.workflow.pending != null)
                Card(
                    color: const Color(0xFFF3DDF0),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(
                              child: SmText(status.isEmpty
                                  ? 'Yarım kalan işlem'
                                  : status)),
                          if (hasSequence || widget.workflow.pending != null)
                            TextButton(
                                key: const Key('recover-tryon'),
                                onPressed: busy ? null : restoreRun,
                                child: const SmText('Kurtar')),
                        ]))),
              if (busy)
                TextButton(
                    onPressed: () {
                      final waiting = timer?.isActive == true;
                      timer?.cancel();
                      cancelled = true;
                      widget.workflow.cancel();
                      checkpoint();
                      if (waiting) setBusy(false);
                      setState(() => status =
                          'İşlem cihazda durduruldu. Kullanılan jetonlar geri yüklenmez; sonucu Kurtar ile kontrol et.');
                    },
                    child: const SmText('Duraklat')),
            ]));
  }
}
