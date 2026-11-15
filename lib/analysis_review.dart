import 'package:material_ui/material_ui.dart';
import 'closet.dart';
import 'stylemuse_api.dart';
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

class AnalysisReviewPage extends StatefulWidget {
  const AnalysisReviewPage(
      {super.key, required this.store, this.workflow, this.confirmTokens, this.manualCrop});
  final Future<void> Function()? manualCrop;
  final ClosetStore store;
  final TokenWorkflowController? workflow;
  final TokenConfirmation? confirmTokens;
  @override
  State<AnalysisReviewPage> createState() => _AnalysisReviewPageState();
}

class _AnalysisReviewPageState extends State<AnalysisReviewPage> {
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
  Future<void> enhance() async {
    final job = widget.store.review?['job_id'];
    if (job is! String ||
        widget.workflow == null ||
        widget.confirmTokens == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.workflow!.enhance(
          job, [for (final i in selected) parts[i]['id'].toString()],
          confirm: widget.confirmTokens!);
      if (result == null) return;
      final updated = (result['items'] as List)
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      for (final part in updated) {
        if (!safeImage(part['image']))
          throw const FormatException('Invalid enhancement image');
      }
      for (final part in updated) {
        final index = parts
            .indexWhere((x) => x['id'].toString() == part['id'].toString());
        if (index >= 0)
          parts[index] = {
            ...parts[index],
            'image': part['image'],
            'enhanced': true
          };
      }
      await widget.store.saveReview({...widget.store.review!, 'items': parts});
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
          appBar: AppBar(title: SmText(detail
              ? 'Seçilen parçaların analizi' : 'Fotoğraf analizi · Ürün seçimi')),
          body: SafeArea(
              child: Column(children: [
            Expanded(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 32, child: ListView(children: [
                  for (var i = 0; i < parts.length; i++)
                    if (!detail || selected.contains(i))
                      Card(child: Column(children: [
                        SizedBox(height: 90, child: photo(
                          (parts[i]['image'] ?? parts[i]['preview']) as String? ?? '',
                          fit: BoxFit.contain)),
                        SmText(parts[i]['category'] as String),
                        if (!detail) Checkbox(
                          value: selected.contains(i),
                          onChanged: busy ? null : (value) => setState(() {
                            if (value == true) { selected.add(i); }
                            else { selected.remove(i); }
                          })),
                      ])),
                ])),
                const SizedBox(width: 8),
                Expanded(flex: 68, child: ColoredBox(color: const Color(0xFFF5E7F4),
                  child: photo(
                    (widget.store.review?['sourceImage'] ??
                      (parts.isEmpty ? '' : parts.first['image'] ?? parts.first['preview'])) as String? ?? '',
                    fit: BoxFit.contain))),
              ]),
            )),
            SmText('${selected.length} ürün seçili'),
            if (error != null) SmText(error!),
            if (!detail)
              FilledButton(
                onPressed: selected.isEmpty ? null : () => setState(() => detail = true),
                child: const SmText('Seçilen parçaları incele')),
            if (detail)
              Flexible(child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(12), children: [
                for (final i in selected)
                  DropdownButtonFormField<String>(
                    key: ValueKey('review-category-$i'),
                    initialValue: parts[i]['category'] as String,
                    decoration: InputDecoration(labelText:
                      translate('Ürün ${i + 1}', widget.store.language)),
                    items: [
                      for (final c in wardrobeCategories)
                        DropdownMenuItem(value: c, child: SmText(c)),
                    ],
                    onChanged: busy ? null : (c) => setState(() => parts[i]['category'] = c),
                  ),
              ])),
            if (detail)
              TextButton(
                onPressed: busy ? null : () => setState(() => detail = false),
                child: const SmText('Ürün seçimine geri dön')),
            if (detail && widget.workflow != null)
              OutlinedButton.icon(
                  key: const Key('enhance-analysis'),
                  onPressed: busy || selected.isEmpty ? null : enhance,
                  icon: const Icon(Icons.auto_awesome),
                  label: SmText(
                      '${selected.length * 2} Stil Jetonu · ${translate('İyileştir', widget.store.language)}')),
            if (widget.manualCrop != null && safeImage(widget.store.review?['sourceImage']))
              OutlinedButton(
                onPressed: busy ? null : () async {
                  setState(() => busy = true);
                  try {
                    await widget.manualCrop!();
                  } catch (_) {
                    if (mounted) setState(() => error = 'Kıyafet kaydedilemedi. Telefonun depolama alanını kontrol et.');
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
                child: const SmText('Elle kırp'),
              ),
            TextButton(
              onPressed: busy ? null : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialog) => LocalStrings(language: widget.store.language,
                    child: AlertDialog(
                      content: const SmText('Analizi iptal edersen kaydedilmemiş sonuçlar silinir. Kullanılan Stil Jetonu geri yüklenmez. Analiz iptal edilsin mi?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const SmText('Vazgeç')),
                        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const SmText('Onayla')),
                      ],
                    )),
                );
                if (confirmed != true || !mounted || busy) return;
                setState(() => busy = true);
                try {
                  await widget.store.saveReview(null);
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (mounted) setState(() { busy = false; error = 'Kaydedilemedi.'; });
                }
              },
              child: const SmText('Analizi iptal et'),
            ),
            if (detail) Padding(
                padding: const EdgeInsets.all(16),
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
