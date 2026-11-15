import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'closet.dart';
import 'localization.dart';
import 'main.dart' show LocalStrings, SmText;

class BackupPage extends StatefulWidget {
  const BackupPage(
      {super.key, required this.store, this.readBackup, this.writeBackup});
  final ClosetStore store;
  final Future<String?> Function()? readBackup;
  final Future<void> Function(String)? writeBackup;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool busy = false;
  String status = '';
  String tr(String s) => translate(s, widget.store.language);
  Future<bool> confirm(String message) async =>
      await showDialog<bool>(
          context: context,
          builder: (dialog) =>
              AlertDialog(content: Text(tr(message)), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(tr('Vazgeç'))),
                FilledButton(
                    key: const Key('backup-confirm'),
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(tr('Onayla')))
              ])) ??
      false;
  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      status = '';
    });
    try {
      await action();
    } catch (_) {
      if (mounted)
        setState(() => status =
            'İşlem tamamlanamadı. Dosyayı ve depolama alanını kontrol et.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    final data = jsonEncode(widget.store.snapshot());
    if (widget.writeBackup != null) {
      await widget.writeBackup!(data);
    } else {
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/stylemuse-yedek-${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(data, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')],
          subject: 'StyleMuse');
    }
    if (mounted) setState(() => status = 'Yedek hazır.');
  }

  Future<void> restore() async {
    String? encoded;
    if (widget.readBackup != null) {
      encoded = await widget.readBackup!();
    } else {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null) return;
      final file = result.files.single;
      if (file.size > 100 * 1024 * 1024)
        throw const FormatException('Backup too large');
      encoded = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();
    }
    if (encoded == null || !mounted) return;
    validateBackup(jsonDecode(encoded));
    if (!await confirm(
        'Yedekte bulunan veriler bu cihazdaki ilgili kayıtların yerini alacak. Geri yüklensin mi?'))
      return;
    await widget.store.restore(encoded);
    if (mounted) setState(() => status = 'Yedek geri yüklendi.');
  }

  Future<void> reset() async {
    if (!await confirm(
        'Dolaptaki tüm kıyafetler ve kayıtlı kombinler silinecek. Emin misin?'))
      return;
    if (!await confirm(
        'Bu işlem geri alınamaz. Tüm kıyafet ve kombinleri silmek istediğinden emin misin?'))
      return;
    await widget.store.resetWardrobe();
    if (mounted) setState(() => status = 'Dolap sıfırlandı.');
  }

  @override
  Widget build(BuildContext context) => LocalStrings(
      language: widget.store.language,
      child: Scaffold(
          appBar: AppBar(title: const SmText('Veri yedekleme')),
          body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(20), children: [
            const Icon(Icons.cloud_download_outlined,
                size: 64, color: Color(0xFFCBA2F2)),
            const SizedBox(height: 20),
            const SmText(
                'Kıyafetlerin, kombinlerin ve profilin bu cihazda saklanır. Yedeğini güvenli bir yerde tut.'),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: busy ? null : () => run(export),
                icon: const Icon(Icons.ios_share),
                label: const SmText('Verilerimi yedekle ↓')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: busy ? null : () => run(restore),
                icon: const Icon(Icons.restore),
                label: const SmText('Yedekten geri yükle ↑')),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),
            TextButton.icon(
                onPressed: busy ? null : () => run(reset),
                icon: const Icon(Icons.delete_forever_outlined,
                    color: Colors.orangeAccent),
                label: const SmText('Dolabı sıfırla')),
            if (busy) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            SmText(status),
          ]))));
}
