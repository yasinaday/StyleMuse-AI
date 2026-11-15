import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const wardrobeCategories = [
  'Üst giyim',
  'Alt giyim',
  'Elbise',
  'Çanta',
  'Dış giyim',
  'Aksesuar',
  'Diğer'
];
const appLanguages = ['tr', 'en', 'de', 'ru', 'ar', 'fr', 'hi', 'zh', 'ja'];

class ClosetItem {
  const ClosetItem(this.id, this.image, this.category);
  final String id, image, category;
  Map<String, dynamic> toJson() =>
      {'id': id, 'image': image, 'category': category};
  factory ClosetItem.fromJson(Map<String, dynamic> x) => ClosetItem(
      x['id'].toString(), x['image'] as String, x['category'] as String);
}

class ClosetStore extends ChangeNotifier {
  ClosetStore({this.directory, this.memory = false});
  Directory? directory;
  final bool memory;
  List<ClosetItem> items = [];
  List<Map<String, dynamic>> looks = [];
  Map<String, String> profile = {};
  Map<String, dynamic>? review;
  String? tryonResult;
  String language = 'tr';
  Future<void> _queue = Future.value();

  Future<void> restore(String encoded) async {
    if (encoded.length > 100 * 1024 * 1024)
      throw const FormatException('Yedek dosyası 100 MB sınırını aşıyor.');
    final data = normalizeBackup(jsonDecode(encoded));
    final imported = (data['items'] as List)
        .map((x) => ClosetItem.fromJson(Map<String, dynamic>.from(x)))
        .toList();
    final outfits = (data['looks'] as List?)
        ?.map((x) => Map<String, dynamic>.from(x))
        .toList();
    final preferences = Map<String, dynamic>.from(data['preferences'] as Map);
    final style = Map<String, String>.from(
        jsonDecode(preferences['sm-style-profile'] as String? ?? '{}') as Map);
    final name = preferences['sm-name'];
    final avatar = preferences['sm-profile-photo'];
    await _change(() {
      items = imported;
      if (outfits != null) looks = outfits;
      profile = {
        ...style,
        if (name is String) 'name': name,
        if (avatar is String) 'photo': avatar
      };
      language = preferences['sm-language'] as String? ?? 'tr';
    });
  }

  Future<void> load() async {
    if (memory) return;
    directory ??= await getApplicationDocumentsDirectory();
    await directory!.create(recursive: true);
    final file = File('${directory!.path}/closet.json');
    if (await file.exists()) {
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      items = (data['items'] as List)
          .map((x) => ClosetItem.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      profile = Map<String, String>.from(data['profile'] ?? {});
      looks = (data['looks'] as List? ?? [])
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      tryonResult = data['tryonResult'] as String?;
      review = data['review'] == null
          ? null
          : Map<String, dynamic>.from(data['review'] as Map);
      language = data['language'] as String? ?? 'tr';
    } else {
      final legacy = File('${directory!.path}/wardrobe/items.json');
      if (await legacy.exists()) {
        final migrated = <ClosetItem>[];
        for (final raw in jsonDecode(await legacy.readAsString()) as List) {
          final id = raw['id'] as String;
          final category = raw['category'] as String;
          if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(id) ||
              !wardrobeCategories.contains(category))
            throw const FormatException('Invalid legacy wardrobe');
          final bytes =
              await File('${directory!.path}/wardrobe/$id.jpg').readAsBytes();
          migrated.add(ClosetItem(
              id, 'data:image/jpeg;base64,${base64Encode(bytes)}', category));
        }
        await _change(() => items = migrated);
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> snapshot() => {
        'version': 2,
        'items': items.map((x) => x.toJson()).toList(),
        'looks': looks,
        'profile': profile,
        'language': language,
        'review': review,
        'tryonResult': tryonResult,
        'preferences': {
          'sm-language': language,
          'sm-name': profile['name'],
          'sm-style-profile': jsonEncode(profile),
          'sm-profile-photo': profile['photo']
        }
      };

  Future<void> _change(void Function() mutate) {
    final next = _queue.catchError((Object _) {}).then((_) async {
      final oldItems = items;
      final oldLooks = looks;
      final oldReview = review;
      final oldTryon = tryonResult;
      final oldProfile = profile;
      final oldLanguage = language;
      mutate();
      try {
        if (!memory) {
          directory ??= await getApplicationDocumentsDirectory();
          await directory!.create(recursive: true);
          final file = File('${directory!.path}/closet.tmp');
          await file.writeAsString(jsonEncode(snapshot()), flush: true);
          await file.rename('${directory!.path}/closet.json');
        }
      } catch (_) {
        items = oldItems;
        looks = oldLooks;
        review = oldReview;
        tryonResult = oldTryon;
        profile = oldProfile;
        language = oldLanguage;
        rethrow;
      }
      notifyListeners();
    });
    _queue = next;
    return next;
  }

  Future<void> addGarment({required String image, required String category}) =>
      _change(() {
        items = [
          ...items,
          ClosetItem(
              DateTime.now().microsecondsSinceEpoch.toString(), image, category)
        ];
      });
  Future<void> saveTryOn(String? image) => _change(() {
        tryonResult = image;
      });
  Future<void> saveReview(Map<String, dynamic>? data) => _change(() {
        review = data == null
            ? null
            : jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
      });
  Future<void> acceptReview(List<Map<String, dynamic>> selected) => _change(() {
        final stamp = DateTime.now().microsecondsSinceEpoch;
        final additions = <ClosetItem>[];
        for (var i = 0; i < selected.length; i++) {
          final x = selected[i];
          final image = x['image'] ?? x['preview'];
          if (!safeImage(image) || !wardrobeCategories.contains(x['category']))
            throw const FormatException('Invalid result');
          additions.add(ClosetItem(
              '${stamp}_$i', image as String, x['category'] as String));
        }
        items = [...items, ...additions];
        review = null;
      });
  Future<void> editGarment(String id, {String? category, String? image}) =>
      _change(() {
        if (category != null && !wardrobeCategories.contains(category))
          throw const FormatException('Invalid category');
        items = [
          for (final item in items)
            if (item.id == id)
              ClosetItem(id, image ?? item.image, category ?? item.category)
            else
              item
        ];
      });
  Future<void> resetWardrobe() => _change(() {
        items = [];
        looks = [];
      });
  Future<void> deleteGarment(String id) => _change(() {
        items = items.where((x) => x.id != id).toList();
      });
  Future<void> saveLook(List<String> ids,
          {String occasion = 'Günlük',
          String style = 'Rahat ve şık',
          String? aiImage}) =>
      _change(() {
        final selected = items.where((x) => ids.contains(x.id)).toList();
        final categories = selected.map((x) => x.category).toSet();
        if (aiImage == null &&
            !categories.contains('Elbise') &&
            !(categories.contains('Üst giyim') &&
                categories.contains('Alt giyim')))
          throw const FormatException(
              'Kombin için üst ve alt giyim ya da elbise seçmelisin.');
        looks = [
          ...looks,
          {
            'images': selected.map((x) => x.image).toList(),
            'itemIds': ids,
            'occasion': occasion,
            'style': style,
            'date': DateTime.now().toIso8601String(),
            'aiImage': aiImage
          }
        ];
      });
  Future<void> updateProfile(Map<String, String> values, {String? language}) =>
      _change(() {
        profile = {...profile, ...values};
        if (language != null) this.language = language;
      });
}

bool safeImage(Object? image) =>
    image is String &&
    image.length <= 30 * 1024 * 1024 &&
    RegExp(r'^data:image/(?:jpeg|png|webp|gif);base64,[A-Za-z0-9+/]+={0,2}$')
        .hasMatch(image);
bool safeOutfitPhoto(Object? value) {
  if (safeImage(value)) return true;
  if (value is! String || value.contains(RegExp(r'\s'))) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      const {'fal.media', 'v3.fal.media', 'v3b.fal.media'}.contains(uri.host);
}

void validateBackup(Object? raw) {
  normalizeBackup(raw);
}

Map<String, dynamic> normalizeBackup(Object? raw) {
  if (raw is Map<String, dynamic> && raw['version'] == 1) {
    final items = jsonDecode(raw['sm-items'] as String? ?? 'null');
    final looks = jsonDecode(raw['sm-combos'] as String? ?? 'null');
    if (items is! List) throw const FormatException('Invalid legacy backup');
    final checked = normalizeBackup({
      'version': 2,
      'items': [
        for (var i = 0; i < items.length; i++)
          if (items[i] is String)
            {'id': i, 'image': items[i], 'category': 'Diğer'}
          else items[i],
      ],
      'looks': looks ?? [],
      'preferences': raw,
    });
    if (looks == null) checked['looks'] = null;
    return checked;
  }
  Never invalid() =>
      throw const FormatException('Geçerli bir StyleMuse yedek dosyası seç.');
  if (raw is! Map<String, dynamic> ||
      raw['version'] != 2 ||
      raw['items'] is! List ||
      raw['looks'] is! List ||
      raw['preferences'] is! Map) invalid();
  final ids = <String>{};
  for (final x in raw['items'] as List) {
    if (x is! Map ||
        !safeImage(x['image']) ||
        !wardrobeCategories.contains(x['category']) ||
        x['id'] == null ||
        !RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(x['id'].toString()) ||
        !ids.add(x['id'].toString())) invalid();
  }
  for (final x in raw['looks'] as List) {
    if (x is! Map ||
        x['images'] is! List ||
        !(x['images'] as List).every(safeImage) ||
        (x['aiImage'] != null && !safeOutfitPhoto(x['aiImage'])) ||
        (x['occasion'] != null && x['occasion'] is! String) ||
        (x['date'] != null && x['date'] is! String)) invalid();
    if (x['itemIds'] != null &&
        (x['itemIds'] is! List ||
            !(x['itemIds'] as List).every((id) => id is String || id is num)))
      invalid();
  }
  final prefs = raw['preferences'] as Map;
  for (final key in [
    'sm-language',
    'sm-name',
    'sm-profile-photo',
    'sm-style-profile'
  ]) {
    if (prefs[key] != null && prefs[key] is! String) invalid();
  }
  if (prefs['sm-language'] != null &&
      !appLanguages.contains(prefs['sm-language'])) invalid();
  if (prefs['sm-profile-photo'] != null &&
      !safeImage(prefs['sm-profile-photo'])) invalid();
  if (prefs['sm-style-profile'] != null) {
    final p = jsonDecode(prefs['sm-style-profile'] as String);
    if (p is! Map || p.values.any((v) => v is! String)) invalid();
  }
  return Map<String, dynamic>.of(raw);
}
