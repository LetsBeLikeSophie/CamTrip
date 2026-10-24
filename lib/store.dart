import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'demo.dart';
import 'models.dart';
import 'photo.dart';
import 'usage_log.dart';

/// Everything is stored on the device only, in one JSON file plus the
/// copied photos. Nothing here is sent anywhere. The web preview keeps
/// sample data in memory only.
class AppStore extends ChangeNotifier {
  final List<Trip> trips = [];
  final List<Capture> captures = [];
  String scriptKey = 'japanese';

  /// Language to translate into. null follows the phone language.
  String? targetLang;
  late Directory _dir;

  /// True when the saved data could not be read at start-up.
  bool loadFailed = false;

  /// Whether the user agreed to keep usage events. null = not asked yet.
  bool? logConsent;
  UsageLog usage = UsageLog(null);

  File get _file => File('${_dir.path}/camtrip.json');
  Directory get photoDir => Directory('${_dir.path}/photos');

  Future<void> load() async {
    if (kIsWeb) {
      logConsent = false;
      _loadDemo();
      notifyListeners();
      return;
    }
    _dir = await getApplicationDocumentsDirectory();
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }
    usage = UsageLog(File('${_dir.path}/usage_log.jsonl'));
    await usage.load();
    if (await _file.exists()) {
      try {
        final data = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        trips
          ..clear()
          ..addAll((data['trips'] as List)
              .map((e) => Trip.fromJson(e as Map<String, dynamic>)));
        captures
          ..clear()
          ..addAll((data['captures'] as List)
              .map((e) => Capture.fromJson(e as Map<String, dynamic>)));
        scriptKey = (data['scriptKey'] as String?) ?? 'japanese';
        targetLang = data['targetLang'] as String?;
        logConsent = data['logConsent'] as bool?;
      } catch (e) {
        // Keep the broken file so the next save does not wipe the old data.
        debugPrint('CamTrip: could not read saved data: $e');
        trips.clear();
        captures.clear();
        final stamp = DateTime.now().millisecondsSinceEpoch;
        await _file.rename('${_dir.path}/camtrip.broken-$stamp.json');
        loadFailed = true;
      }
    }
    notifyListeners();
  }

  void _loadDemo() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 2));
    final trip = Trip(
      id: 'demo-trip',
      country: '일본',
      city: '도쿄',
      langs: ['ja'],
      startAt: start,
      lastAt: now.subtract(const Duration(hours: 20)),
    );
    trips.add(trip);
    final japanese = demoSamples.where((s) => s.lang == 'ja').toList();
    for (var i = 0; i < japanese.length; i++) {
      final s = japanese[i];
      final text = s.blocks.map((b) => '${b.source} ${b.translated}').join(' ');
      captures.add(Capture(
        id: 'demo-$i',
        tripId: trip.id,
        imagePath: s.asset,
        sourceLang: s.lang,
        at: start.add(Duration(hours: 6 * i)),
        category: guessCategory(text),
        blocks: s.blocks,
      ));
    }
  }

  /// Records a usage event only when the user agreed. Pass action names
  /// and counts, never what the user photographed or wrote.
  void track(String event, [Map<String, Object?> props = const {}]) {
    if (logConsent == true) usage.add(event, props);
  }

  Future<void> setLogConsent(bool agreed) async {
    logConsent = agreed;
    if (!agreed) await usage.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    final data = {
      'trips': trips.map((t) => t.toJson()).toList(),
      'captures': captures.map((c) => c.toJson()).toList(),
      'scriptKey': scriptKey,
      'targetLang': targetLang,
      'logConsent': logConsent,
    };
    // Write to a temp file first so a crash mid-write cannot corrupt the data.
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(_file.path);
  }

  Trip? get currentTrip {
    if (trips.isEmpty) return null;
    final sorted = [...trips]..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return sorted.first;
  }

  /// Spec S06: ask about a new trip when the language is new for the
  /// current trip, or when the last capture was more than 3 days ago.
  bool needsNewTrip(String lang, DateTime now) {
    final t = currentTrip;
    if (t == null) return true;
    if (now.difference(t.lastAt).inDays > 3) return true;
    if (lang != 'und' && !t.langs.contains('und') && !t.langs.contains(lang)) return true;
    return false;
  }

  /// The user kept the current trip for a new language: remember it so we
  /// do not ask again for the same language.
  Future<void> addLang(Trip t, String lang) async {
    if (t.langs.contains(lang)) return;
    t.langs.add(lang);
    track('trip_lang_added', {'lang': lang});
    await _save();
    notifyListeners();
  }

  Future<Trip> createTrip({
    required String country,
    required String city,
    required String lang,
    required DateTime now,
  }) async {
    final trip = Trip(
      id: 't${now.microsecondsSinceEpoch}',
      country: country,
      city: city,
      langs: [lang],
      startAt: now,
      lastAt: now,
    );
    trips.add(trip);
    track('trip_created', {'lang': lang});
    await _save();
    notifyListeners();
    return trip;
  }

  Future<Capture> addCapture({
    required Trip trip,
    required String originalImagePath,
    required String sourceLang,
    required List<TextBlockResult> blocks,
    required DateTime now,
  }) async {
    final id = 'c${now.microsecondsSinceEpoch}';
    final savedPath = isAssetPhoto(originalImagePath)
        ? originalImagePath
        : await _copyPhoto(originalImagePath, id);
    final text = blocks.map((b) => '${b.source} ${b.translated}').join(' ');
    final capture = Capture(
      id: id,
      tripId: trip.id,
      imagePath: savedPath,
      sourceLang: sourceLang,
      at: now,
      category: guessCategory(text),
      blocks: blocks,
    );
    captures.add(capture);
    trip.lastAt = now;
    track('capture_saved', {'lang': sourceLang, 'blocks': blocks.length, 'category': capture.category});
    await _save();
    notifyListeners();
    return capture;
  }

  Future<String> _copyPhoto(String originalImagePath, String id) async {
    final fileName = originalImagePath.split(Platform.pathSeparator).last;
    final ext = fileName.contains('.') ? fileName.substring(fileName.lastIndexOf('.')) : '.jpg';
    final saved = await File(originalImagePath).copy('${photoDir.path}/$id$ext');
    return saved.path;
  }

  Future<void> setCategory(Capture c, String category) async {
    track('category_changed', {'from': c.category, 'to': category});
    c.category = category;
    await _save();
    notifyListeners();
  }

  Future<void> deleteCapture(Capture c) async {
    captures.removeWhere((x) => x.id == c.id);
    await deletePhoto(c.imagePath);
    track('capture_deleted');
    // A trip with no translations left is removed with its last capture.
    trips.removeWhere((t) => !captures.any((x) => x.tripId == t.id));
    await _save();
    notifyListeners();
  }

  Future<void> updateTrip(Trip t, {required String country, required String city}) async {
    t.country = country;
    t.city = city;
    await _save();
    notifyListeners();
  }

  Future<void> deleteTrip(Trip t) async {
    final gone = captures.where((c) => c.tripId == t.id).toList();
    for (final c in gone) {
      await deletePhoto(c.imagePath);
    }
    captures.removeWhere((c) => c.tripId == t.id);
    trips.removeWhere((x) => x.id == t.id);
    track('trip_deleted', {'captures': gone.length});
    await _save();
    notifyListeners();
  }

  Future<void> setTargetLang(String? code) async {
    targetLang = code;
    track('target_lang_changed', {'to': code ?? 'phone'});
    await _save();
    notifyListeners();
  }

  Future<void> setScript(String key) async {
    scriptKey = key;
    await _save();
    notifyListeners();
  }

  List<Capture> capturesOf(Trip t) {
    final list = captures.where((c) => c.tripId == t.id).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }
}
