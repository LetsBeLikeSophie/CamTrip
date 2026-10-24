import 'dart:typed_data';

import 'package:camtrip/models.dart';
import 'package:camtrip/money.dart';
import 'package:camtrip/palette.dart';
import 'package:camtrip/translator_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('receipt', () {
    test('total comes from the total line, items from the rest', () {
      final r = readReceipt(['領収書', 'コーヒー 480円\nケーキ 520円', '小計 1,000円', '合計 1,000円']);
      expect(r.total, 1000);
      expect(r.items.map((i) => i.name), ['コーヒー', 'ケーキ']);
      expect(r.items.map((i) => i.amount), [480, 520]);
    });

    test('total on the next line', () {
      expect(readReceipt(['合計', '¥2,350']).total, 2350);
    });

    test('without a total word the largest amount is used', () {
      expect(readReceipt(['小笼包 28', '豆浆 6']).total, 28);
    });

    test('receipt words are recognised', () {
      expect(looksLikeReceipt('領収書 合計 1,000円'), isTrue);
      expect(looksLikeReceipt('醤油ラーメン 850円'), isFalse);
    });
  });

  group('spoken amounts', () {
    test('digits with a currency word', () {
      final a = readSpokenAmount('택시 2,800엔 카드가 안 돼서 현금');
      expect(a?.amount, 2800);
      expect(a?.currency, '¥');
    });

    test('korean units', () {
      expect(readSpokenAmount('모찌 2천8백 엔')?.amount, 2800);
      expect(readSpokenAmount('숙소 1만 2천엔')?.amount, 12000);
    });

    test('numbers without a currency are not money', () {
      expect(readSpokenAmount('딸기 모찌 두 개 샀어 2개'), isNull);
    });

    test('formatting', () {
      expect(formatMoney(21400, '¥'), '¥21,400');
      expect(formatMoney(28, '元'), '28元');
    });
  });

  group('language', () {
    test('kana means Japanese even when detected as Chinese', () {
      expect(decideLang('zh', 'ラーメン 850円'), 'ja');
    });

    test('kanji-only signs follow the trip', () {
      expect(decideLang('zh', '渋谷駅 東口', tripLang: 'ja'), 'ja');
      expect(decideLang('zh', '地铁站 出口'), 'zh');
    });

    test('hangul is Korean, latin follows the detector', () {
      expect(decideLang('und', '출구'), 'ko');
      expect(decideLang('fr', 'Sortie'), 'fr');
      expect(decideLang('und', 'EXIT', tripLang: 'ja'), 'ja');
    });
  });

  group('cover palette', () {
    Uint8List image(int w, int h, Color left, Color right) {
      final data = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final c = x < w * 0.6 ? left : right;
          final i = (y * w + x) * 4;
          data[i] = (c.r * 255).round();
          data[i + 1] = (c.g * 255).round();
          data[i + 2] = (c.b * 255).round();
          data[i + 3] = 255;
        }
      }
      return data;
    }

    test('two lights and two darks, dark left and light right', () {
      final r = readCover(image(20, 10, const Color(0xFF2A2F6B), const Color(0xFFF2D7A8)), 20, 10);
      expect(isDark(Color(r.palette.light1)), isFalse);
      expect(isDark(Color(r.palette.light2)), isFalse);
      expect(isDark(Color(r.palette.dark1)), isTrue);
      expect(isDark(Color(r.palette.dark2)), isTrue);
      expect(r.darkLeft, isTrue);
      expect(r.darkRight, isFalse);
    });

    test('a loud color is calmed down', () {
      final r = readCover(image(10, 10, const Color(0xFFFF00FF), const Color(0xFFFF00FF)), 10, 10);
      expect(HSLColor.fromColor(Color(r.palette.light1)).saturation, lessThanOrEqualTo(0.36));
    });
  });

  test('old saved captures still load', () {
    final c = Capture.fromJson({
      'id': 'c1',
      'tripId': 't1',
      'imagePath': '/x.jpg',
      'sourceLang': 'ja',
      'at': DateTime(2026, 10, 1).toIso8601String(),
      'category': '영수증',
      'blocks': <dynamic>[],
    });
    expect(c.kind, CaptureKind.receipt);
    expect(c.category, '식비');
    expect(c.items, isEmpty);
  });
}
