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

class Capture {
  final String id;
  final String tripId;
  final String imagePath;
  final String sourceLang;
  final DateTime at;
  String category;
  final List<TextBlockResult> blocks;

  Capture({
    required this.id,
    required this.tripId,
    required this.imagePath,
    required this.sourceLang,
    required this.at,
    required this.category,
    required this.blocks,
  });

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
        'category': category,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory Capture.fromJson(Map<String, dynamic> j) => Capture(
        id: j['id'] as String,
        tripId: j['tripId'] as String,
        imagePath: j['imagePath'] as String,
        sourceLang: j['sourceLang'] as String,
        at: DateTime.parse(j['at'] as String),
        category: j['category'] as String,
        blocks: (j['blocks'] as List)
            .map((e) => TextBlockResult.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Trip {
  final String id;
  String country;
  String city;
  /// Languages seen on this trip. The first one started the trip.
  final List<String> langs;
  final DateTime startAt;
  DateTime lastAt;

  Trip({
    required this.id,
    required this.country,
    required this.city,
    required this.langs,
    required this.startAt,
    required this.lastAt,
  });

  String get lang => langs.first;

  String get name {
    final place = city.trim().isNotEmpty ? city.trim() : country.trim();
    return '$place ${startAt.month}월';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'country': country,
        'city': city,
        'lang': lang,
        'langs': langs,
        'startAt': startAt.toIso8601String(),
        'lastAt': lastAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'] as String,
        country: j['country'] as String,
        city: j['city'] as String,
        langs: (j['langs'] as List?)?.cast<String>().toList() ?? [j['lang'] as String],
        startAt: DateTime.parse(j['startAt'] as String),
        lastAt: DateTime.parse(j['lastAt'] as String),
      );
}

const categories = ['메뉴', '교통', '숙소', '쇼핑', '영수증', '기타'];

/// Very small keyword guess. The real app will let the LLM tag it.
String guessCategory(String text) {
  final t = text.toLowerCase();
  bool any(List<String> words) => words.any((w) => t.contains(w.toLowerCase()));
  if (any(['合計', '領収', '小計', 'total', 'receipt', '发票', '영수증', '합계'])) {
    return '영수증';
  }
  if (any(['駅', '線', '出口', '改札', '番線', 'station', 'exit', 'platform', '站', '出口'])) {
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
    case 'th':
      return '태국';
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
