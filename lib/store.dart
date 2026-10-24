import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'demo.dart';
import 'models.dart';
import 'money.dart';
import 'palette.dart';
import 'photo.dart';
import 'usage_log.dart';

/// Everything is stored on the device only, in one JSON file plus the
/// copied photos. Nothing here is sent anywhere. The web preview keeps
/// sample data in memory only.
class AppStore extends ChangeNotifier {
  final List<Trip> trips = [];
  final List<Capture> captures = [];
  final List<Memo> memos = [];

  /// Text recognition script that worked last time, tried first next time.
  String scriptKey = 'japanese';

  /// Language to translate into. null follows the phone language.
  String? targetLang;
  late Directory _dir;

  /// True when the saved data could not be read at start-up.
  bool loadFailed = false;

  /// Whether the user agreed to keep usage events. null = not asked yet.
  bool? logConsent;

  /// The first-run screen has been seen.
  bool onboarded = false;
  UsageLog usage = UsageLog(null);

  File get _file => File('${_dir.path}/camtrip.json');
  Directory get photoDir => Directory('${_dir.path}/photos');

  Future<void> load() async {
    if (kIsWeb) {
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
        memos
          ..clear()
          ..addAll(((data['memos'] as List?) ?? const [])
              .map((e) => Memo.fromJson(e as Map<String, dynamic>)));
        scriptKey = (data['scriptKey'] as String?) ?? 'japanese';
        targetLang = data['targetLang'] as String?;
        logConsent = data['logConsent'] as bool?;
        // People who answered the old consent dialog have seen the start.
        onboarded = (data['onboarded'] as bool?) ?? logConsent != null;
      } catch (e) {
        // Keep the broken file so the next save does not wipe the old data.
        debugPrint('CamTrip: could not read saved data: $e');
        trips.clear();
        captures.clear();
        memos.clear();
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
      lastAt: now.subtract(const Duration(hours: 1)),
    );
    trips.add(trip);
    final japanese = demoSamples.where((s) => s.lang == 'ja').toList();
    for (var i = 0; i < japanese.length; i++) {
      final s = japanese[i];
      captures.add(_buildCapture(
        id: 'demo-$i',
        trip: trip,
        imagePath: s.asset,
        sourceLang: s.lang,
        blocks: s.blocks,
        at: start.add(Duration(hours: 9 * i + 9)),
      ));
    }
    memos.add(Memo(
      id: 'demo-memo',
      tripId: trip.id,
      at: now.subtract(const Duration(hours: 2)),
      text: '택시 2,800엔, 카드가 안 돼서 현금으로 냈어',
      amount: 2800,
      currency: '¥',
    ));
    setCover(trip, japanese.first.asset);
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

  Future<void> finishOnboarding({required bool logs}) async {
    onboarded = true;
    await setLogConsent(logs);
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    final data = {
      'trips': trips.map((t) => t.toJson()).toList(),
      'captures': captures.map((c) => c.toJson()).toList(),
      'memos': memos.map((m) => m.toJson()).toList(),
      'scriptKey': scriptKey,
      'targetLang': targetLang,
      'logConsent': logConsent,
      'onboarded': onboarded,
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

  /// Ask about a new trip when the language is new for the current trip,
  /// or when the last record was more than 3 days ago.
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

  Capture _buildCapture({
    required String id,
    required Trip trip,
    required String imagePath,
    required String sourceLang,
    required List<TextBlockResult> blocks,
    required DateTime at,
  }) {
    final text = blocks.map((b) => '${b.source} ${b.translated}').join(' ');
    final receipt = looksLikeReceipt(text);
    final reading = receipt ? readReceipt(blocks.map((b) => b.source).toList()) : null;
    return Capture(
      id: id,
      tripId: trip.id,
      imagePath: imagePath,
      sourceLang: sourceLang,
      at: at,
      kind: receipt ? CaptureKind.receipt : CaptureKind.menu,
      category: receipt ? guessExpenseCategory(text) : guessCategory(text),
      blocks: blocks,
      amount: reading?.total,
      currency: receipt ? currencyFor(sourceLang) : null,
      items: _translatedItems(reading, blocks),
    );
  }

  /// Receipt items read from the original text, shown with the translated
  /// line when the same block has one.
  List<ReceiptItem> _translatedItems(ReceiptReading? reading, List<TextBlockResult> blocks) {
    if (reading == null) return const [];
    return [
      for (final item in reading.items)
        ReceiptItem(
          blocks
                  .where((b) => b.source.contains(item.name) && b.translated != b.source)
                  .map((b) => b.translated.replaceAll(RegExp(r'[\d,.¥￥円元]+'), '').trim())
                  .where((t) => t.isNotEmpty)
                  .firstOrNull ??
              item.name,
          item.amount,
        ),
    ];
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
    final capture = _buildCapture(
      id: id,
      trip: trip,
      imagePath: savedPath,
      sourceLang: sourceLang,
      blocks: blocks,
      at: now,
    );
    captures.add(capture);
    trip.lastAt = now;
    track('capture_saved', {
      'lang': sourceLang,
      'blocks': blocks.length,
      'kind': capture.kind.name,
      'amount_found': capture.amount != null,
    });
    // The first photo of a trip becomes its cover until the user picks one.
    if (trip.coverPath == null) await setCover(trip, savedPath, byUser: false);
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

  /// Uses [path] as the trip cover and takes the trip colors from it.
  Future<void> setCover(Trip trip, String path, {bool byUser = true}) async {
    trip.coverPath = path;
    try {
      final reading = await readCoverPhoto(path);
      trip.palette = reading.palette;
      trip.coverDarkLeft = reading.darkLeft;
      trip.coverDarkRight = reading.darkRight;
    } catch (e) {
      debugPrint('CamTrip: could not read cover colors: $e');
    }
    if (byUser) track('cover_changed');
    await _save();
    notifyListeners();
  }

  /// The photo was a receipt after all, or not.
  Future<void> setKind(Capture c, CaptureKind kind) async {
    if (c.kind == kind) return;
    track('kind_corrected', {'to': kind.name});
    c.kind = kind;
    final text = c.blocks.map((b) => '${b.source} ${b.translated}').join(' ');
    if (kind == CaptureKind.receipt) {
      final reading = readReceipt(c.blocks.map((b) => b.source).toList());
      c.amount ??= reading.total;
      c.currency ??= currencyFor(c.sourceLang);
      if (c.items.isEmpty) c.items = _translatedItems(reading, c.blocks);
      c.category = guessExpenseCategory(text);
    } else {
      c.category = guessCategory(text);
    }
    await _save();
    notifyListeners();
  }

  Future<void> setAmount(Capture c, double? amount) async {
    track('amount_edited');
    c.amount = amount;
    await _save();
    notifyListeners();
  }

  Future<void> setCategory(Capture c, String category) async {
    track('category_changed', {'from': c.category, 'to': category});
    c.category = category;
    await _save();
    notifyListeners();
  }

  Future<Memo> addMemo(Trip trip, String text, DateTime now) async {
    final spoken = readSpokenAmount(text);
    final memo = Memo(
      id: 'm${now.microsecondsSinceEpoch}',
      tripId: trip.id,
      at: now,
      text: text.trim(),
      amount: spoken?.amount,
      currency: spoken?.currency,
    );
    memos.add(memo);
    trip.lastAt = now;
    track('memo_saved', {'amount_found': spoken != null});
    await _save();
    notifyListeners();
    return memo;
  }

  Future<void> deleteMemo(Memo m) async {
    memos.removeWhere((x) => x.id == m.id);
    track('memo_deleted');
    _dropEmptyTrips();
    await _save();
    notifyListeners();
  }

  /// A trip with nothing left in it goes away with its last record.
  void _dropEmptyTrips() {
    trips.removeWhere((t) =>
        !captures.any((x) => x.tripId == t.id) && !memos.any((x) => x.tripId == t.id));
  }

  Future<void> deleteCapture(Capture c) async {
    captures.removeWhere((x) => x.id == c.id);
    await deletePhoto(c.imagePath);
    track('capture_deleted');
    for (final t in trips.where((t) => t.coverPath == c.imagePath)) {
      t.coverPath = null;
    }
    _dropEmptyTrips();
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
    memos.removeWhere((m) => m.tripId == t.id);
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
    if (scriptKey == key) return;
    scriptKey = key;
    await _save();
  }

  List<Capture> capturesOf(Trip t) {
    final list = captures.where((c) => c.tripId == t.id).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  List<Memo> memosOf(Trip t) {
    final list = memos.where((m) => m.tripId == t.id).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  /// Money spent on the trip in its local currency: receipts plus memos
  /// that mention an amount in that currency.
  double spentOf(Trip t, {DateTime? day}) {
    final currency = currencyFor(t.lang);
    bool sameDay(DateTime at) =>
        day == null || (at.year == day.year && at.month == day.month && at.day == day.day);
    var sum = 0.0;
    for (final c in captures) {
      if (c.tripId == t.id && c.isReceipt && c.amount != null && c.currency == currency && sameDay(c.at)) {
        sum += c.amount!;
      }
    }
    for (final m in memos) {
      if (m.tripId == t.id && m.amount != null && m.currency == currency && sameDay(m.at)) {
        sum += m.amount!;
      }
    }
    return sum;
  }

  /// Menu items eaten, counted from food receipts.
  int dishesOf(Trip t) => captures
      .where((c) => c.tripId == t.id && c.isReceipt && c.category == '식비')
      .fold(0, (n, c) => n + (c.items.isEmpty ? 1 : c.items.length));
}
