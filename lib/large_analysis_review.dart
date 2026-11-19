import 'package:material_ui/material_ui.dart';
import 'closet.dart';
import 'stylemuse_api.dart';
import 'processing_photo.dart';
import 'localization.dart';
import 'main.dart' show LocalStrings, SmText, photo;

String normalizeCategory(Object? category) {
  if (wardrobeCategories.contains(category)) return category as String;
  final text = category.toString().toLowerCase();
  if (RegExp('dress|elbise').hasMatch(text)) return 'Elbise';
  if (RegExp('outer|jacket|coat|ceket|mont').hasMatch(text)) return 'Dış giyim';
  if (RegExp('bag|çanta').hasMatch(text)) return 'Çanta';
  if (RegExp('bottom|trouser|pant|skirt|jean|alt').hasMatch(text))
    return 'Alt giyim';
  if (RegExp('top|shirt|blouse|sweater|üst').hasMatch(text)) return 'Üst giyim';
  if (RegExp('access|hat|belt|scarf').hasMatch(text)) return 'Aksesuar';
  return 'Diğer';
}

class LargeAnalysisReviewPage extends StatefulWidget {
  const LargeAnalysisReviewPage(
      {super.key,
      required this.store,
      this.workflow,
      this.confirmTokens,
      this.manualCrop});
  final Future<void> Function()? manualCrop;
  final ClosetStore store;
  final TokenWorkflowController? workflow;
  final TokenConfirmation? confirmTokens;
  @override
  State<LargeAnalysisReviewPage> createState() =>
      _LargeAnalysisReviewPageState();
}

class _LargeAnalysisReviewPageState extends State<LargeAnalysisReviewPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !busy &&
        widget.workflow?.pending?['action'] == 'generate') {
      enhance(recover: true);
    }
  }

  late final parts = (widget.store.review?['items'] as List? ?? [])
      .map((x) => {
            ...Map<String, dynamic>.from(x),
            'category': normalizeCategory(x['category'])
          })
      .toList();
  final selected = <int>{};
  bool detail = false;
  bool busy = false;
  String? error;
  Future<void> enhance({bool recover = false}) async {
    final job = widget.store.review?['job_id'];
    if (job is! String ||
        widget.workflow == null ||
        widget.confirmTokens == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final ids = recover
          ? (widget.workflow!.pending!['inputs']['item_ids'] as List)
              .cast<String>()
          : [for (final i in selected) parts[i]['id'].toString()];
      if (!recover)
        await widget.store
            .saveReview({...widget.store.review!, 'items': parts});
      final result = recover
          ? await widget.workflow!.recover()
          : await widget.workflow!
              .enhance(job, ids, confirm: widget.confirmTokens!);
      if (result == null) return;
      if (widget.workflow!.pending?['inputs']['job_id'] != job)
        throw const FormatException('Wrong review');
      await widget.store.applyReviewEnhancement(result, itemIds: ids);
      parts
        ..clear()
        ..addAll((widget.store.review!['items'] as List)
            .map((x) => Map<String, dynamic>.from(x)));
      await widget.workflow!.acknowledge();
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'İşlem tamamlanamadı. Kurtar düğmesiyle kontrol et.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LocalStrings(
      language: widget.store.language,
      child: Scaffold(
          key: const Key('analysis-review'),
          appBar: AppBar(
              title: SmText(detail
                  ? 'Seçilen parçaların analizi'
                  : 'Fotoğraf analizi · Ürün seçimi')),
          body: SafeArea(
              child: Column(children: [
            Expanded(
                child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        flex: 55,
                        child: ListView(children: [
                          for (var i = 0; i < parts.length; i++)
                            if (!detail || selected.contains(i))
                              Card(
                                  child: Column(children: [
                                SizedBox(
                                    key: ValueKey('review-product-photo-$i'),
                                    height: 220,
                                    child: ProcessingPhoto(
                                        active: busy,
                                        stage: translate(
                                            'İyileştir', widget.store.language),
                                        child: photo(
                                            (parts[i]['image'] ??
                                                        parts[i]['preview'])
                                                    as String? ??
                                                '',
                                            fit: BoxFit.contain))),
                                if (parts[i]['originalImage'] is String &&
                                    parts[i]['enhanced'] == true)
                                  TextButton.icon(
                                      key: ValueKey('revert-enhancement-$i'),
                                      onPressed: busy
                                          ? null
                                          : () async {
                                              await widget.store
                                                  .revertReviewEnhancement(
                                                      parts[i]['id']
                                                          .toString());
                                              if (mounted)
                                                setState(() {
                                                  parts[i] =
                                                      Map<String, dynamic>.from(
                                                          (widget.store.review![
                                                                  'items']
                                                              as List)[i]);
                                                });
                                            },
                                      icon: const Icon(Icons.undo),
                                      label: const SmText('Orijinale dön')),
                                SmText(parts[i]['category'] as String),
                                if (!detail)
                                  Checkbox(
                                      value: selected.contains(i),
                                      onChanged: busy
                                          ? null
                                          : (value) => setState(() {
                                                if (value == true) {
                                                  selected.add(i);
                                                } else {
                                                  selected.remove(i);
                                                }
                                              })),
                              ])),
                        ])),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 45,
                        child: ColoredBox(
                            color: const Color(0xFFF5E7F4),
                            child: photo(
                                (widget.store.review?['sourceImage'] ??
                                            (parts.isEmpty
                                                ? ''
                                                : parts.first['image'] ??
                                                    parts.first['preview']))
                                        as String? ??
                                    '',
                                fit: BoxFit.contain))),
                  ]),
            )),
            SmText('${selected.length} ürün seçili'),
            if (error != null)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(child: SmText(error!)),
                        if (widget.workflow?.pending != null)
                          TextButton(
                              key: const Key('recover-analysis'),
                              onPressed:
                                  busy ? null : () => enhance(recover: true),
                              child: const SmText('Kurtar')),
                      ]))),
            if (!detail)
              FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => setState(() => detail = true),
                  child: const SmText('Seçilen parçaları incele')),
            if (detail)
              Flexible(
                  child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      children: [
                    for (final i in selected)
                      DropdownButtonFormField<String>(
                        key: ValueKey('review-category-$i'),
                        initialValue: parts[i]['category'] as String,
                        decoration: InputDecoration(
                            labelText: translate(
                                'Ürün ${i + 1}', widget.store.language)),
                        items: [
                          for (final c in wardrobeCategories)
                            DropdownMenuItem(value: c, child: SmText(c)),
                        ],
                        onChanged: busy
                            ? null
                            : (c) => setState(() => parts[i]['category'] = c),
                      ),
                  ])),
            if (detail)
              TextButton(
                  onPressed: busy ? null : () => setState(() => detail = false),
                  child: const SmText('Ürün seçimine geri dön')),
            if (detail && widget.workflow != null)
              OutlinedButton.icon(
                  key: const Key('enhance-analysis'),
                  onPressed: busy ||
                          selected.isEmpty ||
                          widget.workflow?.pending != null
                      ? null
                      : () => enhance(),
                  icon: const Icon(Icons.auto_awesome),
                  label: SmText(
                      '${selected.length * 2} Stil Jetonu · ${translate('İyileştir', widget.store.language)}')),
            Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  if (widget.manualCrop != null &&
                      safeImage(widget.store.review?['sourceImage']))
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              try {
                                await widget.manualCrop!();
                              } catch (_) {
                                if (mounted)
                                  setState(() => error =
                                      'Kıyafet kaydedilemedi. Telefonun depolama alanını kontrol et.');
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      child: const SmText('Elle kırp'),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialog) => LocalStrings(
                                  language: widget.store.language,
                                  child: AlertDialog(
                                    content: const SmText(
                                        'Analizi iptal edersen kaydedilmemiş sonuçlar silinir. Kullanılan Stil Jetonu geri yüklenmez. Analiz iptal edilsin mi?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, false),
                                          child: const SmText('Vazgeç')),
                                      FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(dialog, true),
                                          child: const SmText('Onayla')),
                                    ],
                                  )),
                            );
                            if (confirmed != true || !mounted || busy) return;
                            setState(() => busy = true);
                            try {
                              await widget.store.saveReview(null);
                              if (context.mounted) Navigator.pop(context);
                            } catch (_) {
                              if (mounted)
                                setState(() {
                                  busy = false;
                                  error = 'Kaydedilemedi.';
                                });
                            }
                          },
                    child: const SmText('Analizi iptal et'),
                  ),
                ]),
            if (detail)
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                          key: const Key('accept-analysis'),
                          onPressed: busy || selected.isEmpty
                              ? null
                              : () async {
                                  setState(() => busy = true);
                                  try {
                                    await widget.store.acceptReview(
                                        [for (final i in selected) parts[i]]);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (_) {
                                    if (mounted)
                                      setState(() {
                                        busy = false;
                                        error =
                                            'Kıyafet kaydedilemedi. Telefonun depolama alanını kontrol et.';
                                      });
                                  }
                                },
                          icon: const Icon(Icons.check),
                          label: const SmText('Kabul et ve kaydet')))),
          ]))));
}
