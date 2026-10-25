class TextBlockResult {
  final double left;
  final double top;
  final double width;
  final double height;
  final String source;
  final String translated;

  const TextBlockResult({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.source,
    required this.translated,
  });

  Map<String, dynamic> toJson() => {
        'l': left,
        't': top,
        'w': width,
        'h': height,
        'src': source,
        'dst': translated,
      };

  factory TextBlockResult.fromJson(Map<String, dynamic> j) => TextBlockResult(
        left: (j['l'] as num).toDouble(),
        top: (j['t'] as num).toDouble(),
        width: (j['w'] as num).toDouble(),
        height: (j['h'] as num).toDouble(),
        source: j['src'] as String,
        translated: j['dst'] as String,
      );
}

/// What a photo turned out to be. Decided automatically after reading the
/// text; the user only corrects it when it is wrong.
enum CaptureKind { menu, receipt }

class ReceiptItem {
  final String name;
  final double amount;
  const ReceiptItem(this.name, this.amount);

  Map<String, dynamic> toJson() => {'n': name, 'a': amount};
  factory ReceiptItem.fromJson(Map<String, dynamic> j) =>
      ReceiptItem(j['n'] as String, (j['a'] as num).toDouble());
}

class Capture {
  final String id;
  final String tripId;
  final String imagePath;
  final String sourceLang;
  final DateTime at;
  CaptureKind kind;

  /// Menu photos: 메뉴/교통/숙소/쇼핑/기타. Receipts: one of [expenseCategories].
  String category;
  final List<TextBlockResult> blocks;

  /// Receipt total, read from the photo and editable by the user.
  double? amount;
  String? currency;
  List<ReceiptItem> items;

  Capture({
    required this.id,
    required this.tripId,
    required this.imagePath,
    required this.sourceLang,
    required this.at,
    required this.kind,
    required this.category,
    required this.blocks,
    this.amount,
    this.currency,
    this.items = const [],
  });

  bool get isReceipt => kind == CaptureKind.receipt;

  String get summary {
    final first = blocks.isEmpty ? '' : blocks.first.translated;
    return first.replaceAll('\n', ' ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'imagePath': imagePath,
        'sourceLang': sourceLang,
        'at': at.toIso8601String(),
        'kind': kind.name,
        'category': category,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'amount': amount,
        'currency': currency,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory Capture.fromJson(Map<String, dynamic> j) {
    final category = j['category'] as String;
    final kindName = j['kind'] as String?;
    return Capture(
      id: j['id'] as String,
      tripId: j['tripId'] as String,
      imagePath: j['imagePath'] as String,
      sourceLang: j['sourceLang'] as String,
      at: DateTime.parse(j['at'] as String),
      // Saved before kinds existed: old receipts were tagged 영수증.
      kind: kindName != null
          ? CaptureKind.values.byName(kindName)
          : (category == '영수증' ? CaptureKind.receipt : CaptureKind.menu),
      category: category == '영수증' ? '식비' : category,
      blocks: (j['blocks'] as List)
          .map((e) => TextBlockResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      amount: (j['amount'] as num?)?.toDouble(),
      currency: j['currency'] as String?,
      items: ((j['items'] as List?) ?? const [])
          .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A "press and talk" note. Spoken in the user's language, kept as text
/// only (no audio). An amount in it counts as an expense.
class Memo {
  final String id;
  final String tripId;
  final DateTime at;
  String text;
  double? amount;
  String? currency;

  /// Expense category when the memo has an amount, one of [expenseCategories].
  String category;

  /// Confirmed in the evening wrap-up.
  bool sorted;

  Memo({
    required this.id,
    required this.tripId,
    required this.at,
    required this.text,
    this.amount,
    this.currency,
    String? category,
    this.sorted = false,
  }) : category = category ?? guessMemoCategory(text);

  Map<String, dynamic> toJson() => {
        'id': id,
        'tripId': tripId,
        'at': at.toIso8601String(),
        'text': text,
        'amount': amount,
        'currency': currency,
        'category': category,
        'sorted': sorted,
      };

  factory Memo.fromJson(Map<String, dynamic> j) => Memo(
        id: j['id'] as String,
        tripId: j['tripId'] as String,
        at: DateTime.parse(j['at'] as String),
        text: j['text'] as String,
        amount: (j['amount'] as num?)?.toDouble(),
        currency: j['currency'] as String?,
        category: j['category'] as String?,
        sorted: (j['sorted'] as bool?) ?? false,
      );
}

/// Expense category guess for a spoken memo.
String guessMemoCategory(String text) {
  bool any(List<String> words) => words.any(text.contains);
  if (any(['택시', '지하철', '전철', '버스', '기차', '신칸센', '교통', '공항철도', '스이카', '페리'])) return '교통';
  if (any(['호텔', '숙소', '게스트하우스', '료칸', '에어비앤비'])) return '숙소';
  if (any(['샀', '쇼핑', '기념품', '선물', '옷', '화장품', '드럭스토어'])) return '쇼핑';
  if (any(['먹', '마셨', '라멘', '커피', '카페', '식당', '맥주', '모찌', '밥', '간식', '편의점'])) return '식비';
  return '기타';
}

/// Four colors taken from a trip's cover photo: two light, two dark.
class TripPalette {
  final int light1;
  final int light2;
  final int dark1;
  final int dark2;

  const TripPalette(this.light1, this.light2, this.dark1, this.dark2);

  /// Used until a trip has a cover photo.
  static const fallback = TripPalette(0xFFD6DDF0, 0xFFEBDCE8, 0xFF1E2547, 0xFF3B2F5C);

  List<int> toJson() => [light1, light2, dark1, dark2];
  factory TripPalette.fromJson(List<dynamic> j) =>
      TripPalette(j[0] as int, j[1] as int, j[2] as int, j[3] as int);
}

class Trip {
  final String id;
  String country;
  String city;
  /// Languages seen on this trip. The first one started the trip.
  final List<String> langs;
  final DateTime startAt;
  DateTime lastAt;
  String? coverPath;
  TripPalette palette;

  /// Whether the cover photo is dark under the left (title) and right
  /// (date) text on the trips list, so the text can switch to white.
  bool coverDarkLeft;
  bool coverDarkRight;

  Trip({
    required this.id,
    required this.country,
    required this.city,
    required this.langs,
    required this.startAt,
    required this.lastAt,
    this.coverPath,
    this.palette = TripPalette.fallback,
    this.coverDarkLeft = true,
    this.coverDarkRight = true,
  });

  String get lang => langs.first;

  String get place => city.trim().isNotEmpty ? city.trim() : country.trim();

  String get name => '$place ${startAt.month}월';

  /// 1 on the first day of the trip.
  int dayOf(DateTime t) {
    final a = DateTime(startAt.year, startAt.month, startAt.day);
    final b = DateTime(t.year, t.month, t.day);
    return b.difference(a).inDays + 1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'country': country,
        'city': city,
        'lang': lang,
        'langs': langs,
        'startAt': startAt.toIso8601String(),
        'lastAt': lastAt.toIso8601String(),
        'coverPath': coverPath,
        'palette': palette.toJson(),
        'coverDarkLeft': coverDarkLeft,
        'coverDarkRight': coverDarkRight,
      };

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'] as String,
        country: j['country'] as String,
        city: j['city'] as String,
        langs: (j['langs'] as List?)?.cast<String>().toList() ?? [j['lang'] as String],
        startAt: DateTime.parse(j['startAt'] as String),
        lastAt: DateTime.parse(j['lastAt'] as String),
        coverPath: j['coverPath'] as String?,
        palette: j['palette'] == null
            ? TripPalette.fallback
            : TripPalette.fromJson(j['palette'] as List),
        coverDarkLeft: (j['coverDarkLeft'] as bool?) ?? true,
        coverDarkRight: (j['coverDarkRight'] as bool?) ?? true,
      );
}

const categories = ['메뉴', '교통', '숙소', '쇼핑', '기타'];
const expenseCategories = ['식비', '교통', '숙소', '쇼핑', '기타'];

/// Very small keyword guess. The real app will let the LLM tag it.
String guessCategory(String text) {
  final t = text.toLowerCase();
  bool any(List<String> words) => words.any((w) => t.contains(w.toLowerCase()));
  if (any(['駅', '線', '出口', '改札', '番線', 'station', 'exit', 'platform', '站'])) {
    return '교통';
  }
  if (any(['ホテル', 'チェックイン', 'hotel', 'check-in', '酒店', 'フロント'])) {
    return '숙소';
  }
  if (any(['円', '¥', '€', '\$', '元', 'menu', 'メニュー', '定食', 'ラーメン', '菜单'])) {
    return '메뉴';
  }
  return '기타';
}

/// True when the text reads like a receipt rather than a menu or sign.
bool looksLikeReceipt(String text) {
  final t = text.toLowerCase();
  return ['合計', '領収', '小計', 'お会計', 'total', 'receipt', '发票', '合计', '收据', '영수증', '합계']
      .any((w) => t.contains(w.toLowerCase()));
}

/// Expense category guess for a receipt.
String guessExpenseCategory(String text) {
  switch (guessCategory(text)) {
    case '교통':
      return '교통';
    case '숙소':
      return '숙소';
    case '메뉴':
      return '식비';
    default:
      return '기타';
  }
}

/// Rough guess of the country from the source language, used only to
/// prefill the "new trip" question. The user always confirms it.
String guessCountry(String lang) {
  switch (lang) {
    case 'ja':
      return '일본';
    case 'zh':
      return '중국';
    case 'ko':
      return '한국';
    case 'vi':
      return '베트남';
    case 'fr':
      return '프랑스';
    case 'de':
      return '독일';
    case 'es':
      return '스페인';
    case 'it':
      return '이탈리아';
    default:
      return '';
  }
}
