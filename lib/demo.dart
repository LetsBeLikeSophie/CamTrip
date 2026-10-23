/// Sample photos for the web preview (assets/demo). Browsers cannot run
/// ML Kit, so the web build shows these canned results instead.
library;

import 'models.dart';

class DemoSample {
  final String name;
  final String lang;
  final List<TextBlockResult> blocks;
  const DemoSample(this.name, this.lang, this.blocks);

  String get asset => 'assets/demo/$name.jpg';
}

const demoSamples = <DemoSample>[
  DemoSample('menu', 'ja', [
    TextBlockResult(left: 70, top: 91, width: 404, height: 98, source: 'ラーメン', translated: '라멘'),
    TextBlockResult(left: 70, top: 322, width: 489, height: 68, source: '醤油ラーメン 850円', translated: '간장 라멘 850엔'),
    TextBlockResult(left: 70, top: 443, width: 489, height: 67, source: '味噌ラーメン 950円', translated: '된장 라멘 950엔'),
    TextBlockResult(left: 70, top: 562, width: 333, height: 68, source: '替え玉 150円', translated: '면 추가 150엔'),
    TextBlockResult(left: 70, top: 892, width: 460, height: 61, source: '食券を買ってください', translated: '식권을 사 주세요'),
  ]),
  DemoSample('station', 'ja', [
    TextBlockResult(left: 70, top: 105, width: 350, height: 120, source: '渋谷駅', translated: '시부야역'),
    TextBlockResult(left: 70, top: 372, width: 371, height: 76, source: '山手線 2番線', translated: '야마노테선 2번 승강장'),
    TextBlockResult(left: 70, top: 513, width: 277, height: 75, source: '東口 出口', translated: '동쪽 출구'),
    TextBlockResult(left: 70, top: 813, width: 344, height: 69, source: '改札はこちら', translated: '개찰구는 이쪽'),
  ]),
  DemoSample('receipt', 'ja', [
    TextBlockResult(left: 70, top: 84, width: 290, height: 103, source: '領収書', translated: '영수증'),
    TextBlockResult(left: 70, top: 325, width: 371, height: 62, source: 'コーヒー 480円', translated: '커피 480엔'),
    TextBlockResult(left: 70, top: 434, width: 321, height: 63, source: 'ケーキ 520円', translated: '케이크 520엔'),
    TextBlockResult(left: 70, top: 612, width: 370, height: 79, source: '合計 1,000円', translated: '합계 1,000엔'),
  ]),
  DemoSample('hotel', 'ja', [
    TextBlockResult(left: 70, top: 95, width: 406, height: 102, source: 'ホテル 桜', translated: '호텔 사쿠라'),
    TextBlockResult(left: 70, top: 374, width: 499, height: 67, source: 'チェックイン 15:00', translated: '체크인 15:00'),
    TextBlockResult(left: 70, top: 513, width: 483, height: 69, source: 'フロントは2階です', translated: '프런트는 2층입니다'),
  ]),
  DemoSample('street', 'zh', [
    TextBlockResult(left: 70, top: 112, width: 420, height: 118, source: '欢迎光临', translated: '어서 오세요'),
    TextBlockResult(left: 70, top: 384, width: 352, height: 78, source: '小笼包 28元', translated: '샤오롱바오 28위안'),
    TextBlockResult(left: 70, top: 543, width: 372, height: 75, source: '地铁站 出口 B', translated: '지하철역 B 출구'),
  ]),
];
