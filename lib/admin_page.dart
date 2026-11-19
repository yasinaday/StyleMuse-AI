import 'dart:convert';
import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'admin_api.dart';
import 'stylemuse_api.dart';

/// Native private diagnostics. Route visibility is not an authorization boundary.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.api, this.importProducts});
  final AdminApi api;
  final Future<void> Function()? importProducts;
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Map<String, dynamic>? _data;
  bool _busy = false;
  bool _denied = false;
  String _status = '';
  String? _tokenRequest;
  final _amount = TextEditingController();
  final _code = TextEditingController();
  final _credit = TextEditingController();
  static const _encoder = JsonEncoder.withIndent('  ');
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _amount.dispose();
    _code.dispose();
    _credit.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy || _denied) return;
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await operation();
    } on StyleMuseApiException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.status == 401 ||
            error.status == 403 ||
            error.code == 'session_changed') {
          _data = null;
          _denied = true;
          _tokenRequest = null;
          _code.clear();
        }
        _status = 'İşlem tamamlanamadı: ${error.code}';
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _status =
              'İşlem tamamlanamadı. Yeniden göndermeden önce durumu kontrol edin.';
        });
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
        });
    }
  }

  Future<void> _refresh() => _perform(() async {
        final result = await widget.api.overview();
        if (mounted)
          setState(() {
            _data = result;
          });
      });
  Future<void> _requestTokens() => _perform(() async {
        final amount = int.tryParse(_amount.text);
        if (amount == null || amount < 1 || amount > 10000) {
          setState(() {
            _status = '1–10000 arasında tam sayı girin.';
          });
          return;
        }
        final result = await widget.api.requestTokens(amount);
        if (!mounted) return;
        setState(() {
          _tokenRequest = result['request_id'] as String?;
          _code.clear();
          _status =
              'Doğrulama kodu yönetici e-postasına gönderildi. Kod 5 dakika geçerlidir.';
        });
      });
  Future<void> _confirmTokens() => _perform(() async {
        if (_tokenRequest == null || !RegExp(r'^\d{6}$').hasMatch(_code.text)) {
          setState(() {
            _status = '6 haneli kod girin.';
          });
          return;
        }
        final result =
            await widget.api.confirmTokens(_tokenRequest!, _code.text);
        if (!mounted) return;
        setState(() {
          _tokenRequest = null;
          _code.clear();
          _status = 'Jeton bakiyesi: ${result['balance']}';
        });
        final fresh = await widget.api.overview();
        if (mounted)
          setState(() {
            _data = fresh;
          });
      });
  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Widget _section(String title, List<Widget> children) => Card(
      child: ExpansionTile(
          initiallyExpanded: title == 'Başarısız ve yarım kalan işler' ||
              title == 'Analiz geçmişi ve iş ayrıntıları',
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          childrenPadding: const EdgeInsets.all(16),
          children: children));
  Widget _rows(String title, String key, {bool? incomplete}) {
    final raw = _data?[key];
    final rows = raw is List
        ? raw
            .where((row) =>
                incomplete == null ||
                (row is Map &&
                        !['done', 'complete', 'completed', 'succeeded']
                            .contains(row['state'])) ==
                    incomplete)
            .toList()
        : [];
    return _section(title, [
      if (rows.isEmpty)
        const Text('Henüz kayıt yok.')
      else
        ...rows.map<Widget>((row) => ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(row is Map
                ? '${row['id'] ?? row['job'] ?? row['owner'] ?? ''} · ${row['state'] ?? row['outcome'] ?? ''}'
                : 'Kayıt'),
            children: [SelectableText(_encoder.convert(row))]))
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Yönetici ayarları ve bildirimler'),
            actions: [
              IconButton(
                  onPressed: _busy || _denied ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Durumu yenile')
            ]),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_busy) const LinearProgressIndicator(),
          if (_status.isNotEmpty)
            Semantics(
                liveRegion: true,
                child: Padding(
                    padding: const EdgeInsets.all(12), child: Text(_status))),
          if (_denied)
            const Text(
                'Bu sayfa için doğrulanmış yönetici oturumu gerekir. Çıkıp doğru hesapla yeniden giriş yapın.'),
          if (!_denied && _data != null) ...[
            const Text(
                'Son 50 iş ve sınırlı işlem geçmişi. Maskeler ve kategoriler anlamsal olarak doğrulanmış değildir. Yenileme ücretli çıkarım başlatmaz.'),
            _rows('Başarısız ve yarım kalan işler', 'jobs', incomplete: true),
            _rows('Hatalar ve bildirimler', 'errors'),
            _rows('Analiz geçmişi ve iş ayrıntıları', 'jobs',
                incomplete: false),
            OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _perform(() async {
                          await Clipboard.setData(
                              ClipboardData(text: _encoder.convert(_data)));
                          if (mounted)
                            setState(() {
                              _status = 'Güvenli rapor kopyalandı.';
                            });
                        }),
                icon: const Icon(Icons.copy),
                label: const Text('Raporu kopyala')),
            _rows('Parça kimliği, maske ve sağlayıcı eşleşmesi',
                'enhancement_audit'),
            _rows('İşlem maliyet defteri', 'operations'),
            _rows('Jeton bakiyeleri', 'token_balances'),
            _rows('Jeton yükleme geçmişi', 'token_load_history'),
            _section('Jeton Yükle', [
              TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Jeton adedi (1–10000)'),
                  enabled: !_busy),
              FilledButton(
                  onPressed: _busy ? null : _requestTokens,
                  child: const Text('E-posta kodu gönder')),
              if (_tokenRequest != null) ...[
                TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                        labelText: '6 haneli doğrulama kodu'),
                    enabled: !_busy),
                FilledButton(
                    onPressed: _busy ? null : _confirmTokens,
                    child: const Text('Jetonları yükle')),
              ],
              const Text(
                  'Satın alma değildir. Yalnızca mevcut e-posta onaylı yönetici yükleme akışı.'),
            ]),
            _section('Sağlayıcı bakiye takibi', [
              const Text(
                  'Replicate kaydı 24 saatlik yönetici notudur; çıkarım izni veya gerçek ödeme değildir.'),
              TextField(
                  controller: _credit,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Replicate kalan kredi (USD)'),
                  enabled: !_busy),
              OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(() async {
                            final text = _credit.text.trim();
                            if (!RegExp(r'^(?:[0-9]{1,5}|100000)(?:\.[0-9]{1,2})?$')
                                    .hasMatch(text) ||
                                (double.tryParse(text) ?? -1) > 100000) {
                              setState(() {
                                _status =
                                    'Geçerli USD tutarı girin (0–100000).';
                              });
                              return;
                            }
                            final result = await widget.api
                                .recordReplicateCredit(text, _uuid());
                            if (mounted)
                              setState(() {
                                _status =
                                    'Replicate: ${_encoder.convert(result)}';
                              });
                          }),
                  child: const Text('Replicate notunu kaydet')),
              OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(() async {
                            final result = await widget.api.replicateCredit();
                            if (mounted)
                              setState(() {
                                _status =
                                    'Replicate: ${_encoder.convert(result)}';
                              });
                          }),
                  child: const Text('Son Replicate kaydını getir')),
              OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(() async {
                            final result = await widget.api.falCredit();
                            if (mounted)
                              setState(() {
                                _status =
                                    'fal.ai: ${result['available_usd'] ?? 'Kullanılamıyor'} USD';
                              });
                          }),
                  child: const Text('fal.ai bakiyesini sorgula')),
            ]),
            _section('Toplu ürün aktarımı', [
              const Text(
                  'Mevcut dolap korunur. StyleMuse ürün paketini içe aktarın.'),
              OutlinedButton(
                  onPressed: _busy || widget.importProducts == null
                      ? null
                      : () => _perform(widget.importProducts!),
                  child: const Text('Ürün paketini içe aktar')),
              if (widget.importProducts == null)
                const Text('Ürün paketi seçicisi bu kurulumda bağlı değil.'),
            ]),
            _section('Bağlantı durumu ve güvenli ayarlar', [
              SelectableText(_encoder.convert(_data!['settings'])),
              const Text(
                  'Gizli anahtarlar, oturum çerezleri, doğrulama kodları ve kaynak fotoğraflar rapora dahil edilmez. Android yetkilendirmesi mevcut Google hesabını kullanır.'),
              OutlinedButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Yeniden kontrol et')),
            ]),
          ],
        ])),
      );
}
