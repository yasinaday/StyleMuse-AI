import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const StyleMuseApp());

class StyleMuseApp extends StatelessWidget {
  const StyleMuseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'StyleMuse AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF76367C)),
          scaffoldBackgroundColor: const Color(0xFFFFF8FE),
        ),
        home: const WardrobePage(),
      );
}

class Garment {
  const Garment(this.id, this.category);

  factory Garment.fromJson(Map<String, dynamic> json) =>
      Garment(json['id'] as String, json['category'] as String);

  final String id;
  final String category;

  Map<String, String> toJson() => {'id': id, 'category': category};
}

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  static const categories = ['Üst giyim', 'Alt giyim', 'Elbise', 'Dış giyim', 'Çanta'];
  final _picker = ImagePicker();
  late final Future<Directory> _load = _openWardrobe();
  List<Garment> _items = [];
  bool _busy = false;

  Future<Directory> _openWardrobe() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = await Directory('${root.path}/wardrobe').create(recursive: true);
    final index = File('${directory.path}/items.json');
    if (await index.exists()) {
      final entries = jsonDecode(await index.readAsString()) as List<dynamic>;
      _items = entries.map((entry) => Garment.fromJson(entry as Map<String, dynamic>)).toList();
    }
    return directory;
  }

  Future<void> _save(Directory directory, List<Garment> items) async {
    final temporary = File('${directory.path}/items.tmp');
    await temporary.writeAsString(jsonEncode(items), flush: true);
    await temporary.rename('${directory.path}/items.json');
    if (mounted) setState(() => _items = items);
  }

  File _photo(Directory directory, Garment item) => File('${directory.path}/${item.id}.jpg');

  void _notify(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _chooseCategory(String current) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final category in categories)
              ListTile(
                title: Text(category),
                trailing: current == category ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheet, category),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(Directory directory) async {
    setState(() => _busy = true);
    try {
      final picture = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
      if (!mounted || picture == null) return;
      final category = await _chooseCategory(categories.first);
      if (!mounted || category == null) return;
      final item = Garment(DateTime.now().microsecondsSinceEpoch.toString(), category);
      final destination = _photo(directory, item);
      try {
        await picture.saveTo(destination.path);
        await _save(directory, [..._items, item]);
      } catch (_) {
        if (await destination.exists()) await destination.delete();
        rethrow;
      }
    } catch (_) {
      _notify('Fotoğraf kaydedilemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(Directory directory, Garment item) async {
    setState(() => _busy = true);
    try {
      final category = await _chooseCategory(item.category);
      if (category == null || category == item.category || !mounted) return;
      await _save(directory, [
        for (final garment in _items)
          if (garment.id == item.id) Garment(item.id, category) else garment,
      ]);
    } catch (_) {
      _notify('Kategori kaydedilemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Directory directory, Garment item) async {
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Kıyafet silinsin mi?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Sil')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _save(directory, _items.where((garment) => garment.id != item.id).toList());
      final photo = _photo(directory, item);
      if (await photo.exists()) await photo.delete();
    } catch (_) {
      _notify('Silme işlemi tamamlanamadı.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Directory>(
        future: _load,
        builder: (context, snapshot) {
          final directory = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              leading: Padding(
                padding: const EdgeInsets.all(9),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/stylemuse-icon.png', excludeFromSemantics: true),
                ),
              ),
              title: const Text('Giysiler'),
            ),
            floatingActionButton: directory == null
                ? null
                : FloatingActionButton.extended(
                    onPressed: _busy ? null : () => _add(directory),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Kıyafet ekle'),
                  ),
            body: SafeArea(
              child: directory == null
                  ? Center(child: snapshot.hasError
                      ? const Text('Dolap açılamadı.')
                      : const CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('Dolabın boş. Bir kıyafet fotoğrafı ekle.'))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, mainAxisExtent: 220,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  Expanded(child: Image.file(
                                    _photo(directory, item),
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                                  )),
                                  ListTile(
                                    dense: true,
                                    title: Text(item.category),
                                    onTap: _busy ? null : () => _edit(directory, item),
                                    trailing: IconButton(
                                      onPressed: _busy ? null : () => _delete(directory, item),
                                      tooltip: 'Sil',
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          );
        },
      );
}
