import 'models.dart';

/// Local currency symbol for a trip language.
String currencyFor(String lang) {
  switch (lang) {
    case 'ja':
      return '¥';
    case 'zh':
      return '元';
    case 'ko':
      return '₩';
    case 'vi':
      return '₫';
    case 'fr':
    case 'de':
    case 'es':
    case 'it':
      return '€';
    default:
      return '\$';
  }
}

String formatMoney(double amount, String? currency) {
  final whole = amount == amount.roundToDouble();
  final text = whole ? _group(amount.round()) : amount.toStringAsFixed(2);
  final c = currency ?? '';
  return c == '元' ? '$text$c' : '$c$text';
}

String _group(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

final _number = RegExp(r'(\d{1,3}(?:,\d{3})+|\d+)(\.\d{1,2})?');

double? _lastNumber(String line) {
  final all = _number.allMatches(line).toList();
  if (all.isEmpty) return null;
  final m = all.last;
  return double.tryParse('${m.group(1)!.replaceAll(',', '')}${m.group(2) ?? ''}');
}

const _totalWords = ['合計', '合计', '総計', 'お会計', 'total', '합계', '총액', '总计'];
const _skipWords = ['小計', '小计', 'subtotal', '税', 'tax', 'お預', 'お釣', 'change', 'cash', '現金', '点数', '個数'];

class ReceiptReading {
  final double? total;
  final List<ReceiptItem> items;
  const ReceiptReading(this.total, this.items);
}

/// Reads a receipt from its text lines (original language). Finds the line
/// with a total keyword; without one, the largest amount is the total.
ReceiptReading readReceipt(List<String> texts) {
  final lines = [
    for (final t in texts) ...t.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty),
  ];
  bool has(String line, List<String> words) {
    final l = line.toLowerCase();
    return words.any((w) => l.contains(w.toLowerCase()));
  }

  double? total;
  for (var i = 0; i < lines.length; i++) {
    if (!has(lines[i], _totalWords)) continue;
    total = _lastNumber(lines[i]) ?? (i + 1 < lines.length ? _lastNumber(lines[i + 1]) : null);
    if (total != null) break;
  }

  final items = <ReceiptItem>[];
  for (final line in lines) {
    if (has(line, _totalWords) || has(line, _skipWords)) continue;
    final amount = _lastNumber(line);
    if (amount == null || amount <= 0) continue;
    final name = line
        .replaceAll(_number, '')
        .replaceAll(RegExp(r'[¥￥$€₩円元\\*×xX@:：.,\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty) continue;
    items.add(ReceiptItem(name, amount));
  }

  if (total == null && items.isNotEmpty) {
    total = items.map((i) => i.amount).reduce((a, b) => a > b ? a : b);
  }
  if (total != null) items.removeWhere((i) => i.amount > total!);
  return ReceiptReading(total, items);
}

const _units = <String, String>{
  '엔': '¥', '円': '¥', '위안': '元', '元': '元', '달러': '\$', '불': '\$',
  '유로': '€', '원': '₩', '동': '₫',
};

class SpokenAmount {
  final double amount;
  final String currency;
  const SpokenAmount(this.amount, this.currency);
}

/// Finds an amount in a spoken memo such as "택시 2,800엔" or
/// "모찌 2천8백 엔". Needs a currency word so plain counts are ignored.
SpokenAmount? readSpokenAmount(String text) {
  final unitPattern = _units.keys.join('|');
  final m = RegExp(r'((?:\d[\d,]*(?:\.\d+)?\s*[만천백]?\s*)+)\s*(' + unitPattern + r')').firstMatch(text);
  if (m == null) return null;
  final amount = _koreanNumber(m.group(1)!);
  if (amount == null || amount <= 0) return null;
  return SpokenAmount(amount, _units[m.group(2)]!);
}

/// "2,800" → 2800, "2천8백" → 2800, "1만 2천" → 12000.
double? _koreanNumber(String s) {
  final parts = RegExp(r'(\d[\d,]*(?:\.\d+)?)\s*([만천백]?)').allMatches(s);
  double total = 0;
  var any = false;
  for (final p in parts) {
    final n = double.tryParse(p.group(1)!.replaceAll(',', ''));
    if (n == null) continue;
    any = true;
    switch (p.group(2)) {
      case '만':
        total += n * 10000;
      case '천':
        total += n * 1000;
      case '백':
        total += n * 100;
      default:
        total += n;
    }
  }
  return any ? total : null;
}
