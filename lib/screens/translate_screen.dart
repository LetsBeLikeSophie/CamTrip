import 'package:flutter/material.dart';

import '../hold_photo.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';
import '../voice.dart';
import 'receipt_screen.dart';
import 'reply_screen.dart';

const langNames = {
  'ja': '일본어',
  'zh': '중국어',
  'ko': '한국어',
  'en': '영어',
  'fr': '프랑스어',
  'de': '독일어',
  'es': '스페인어',
  'it': '이탈리아어',
  'vi': '베트남어',
};

/// What a sign or menu says. Saved automatically; the photo shows the
/// translation only while pressed.
class TranslateScreen extends StatelessWidget {
  final AppStore store;
  final Capture capture;
  const TranslateScreen({super.key, required this.store, required this.capture});

  String get _title {
    final first = capture.blocks.isEmpty ? '' : capture.blocks.first.translated.trim();
    if (first.isNotEmpty && first.length <= 12 && !first.contains('\n')) return first;
    switch (capture.category) {
      case '메뉴':
        return '메뉴판';
      case '교통':
        return '안내판';
      case '숙소':
        return '숙소 안내';
      default:
        return '찍은 글자';
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(context, '이 기록을 지울까요?', '사진과 번역이 함께 지워져요.');
    if (ok != true) return;
    await store.deleteCapture(capture);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _isReceipt(BuildContext context) async {
    await store.setKind(capture, CaptureKind.receipt);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ReceiptScreen(store: store, capture: capture),
    ));
  }

  Future<void> _listen(BuildContext context, String text) async {
    final ok = await Speaker.instance.say(text, capture.sourceLang);
    if (!ok && context.mounted) {
      toast(context, '이 폰에 ${langNames[capture.sourceLang] ?? '이 언어'} 음성이 없어요. 폰 설정의 "텍스트 음성 변환"에서 받을 수 있어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = store.trips.where((t) => t.id == capture.tripId).firstOrNull;
    final light1 = trip?.light1 ?? const Color(0xFFD6DDF0);
    final dark1 = trip?.dark1 ?? const Color(0xFF1E2547);
    final place = trip?.place ?? '';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TopBar(
              leading: const BackArrow(),
              actions: [
                Text('자동 저장됨', style: body(12, color: C.sub)),
                IconButton(
                  tooltip: '지우기',
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline, color: C.navy),
                ),
              ],
            ),
            ContextBand(
              label: [if (place.isNotEmpty) place, hm(capture.at), langNames[capture.sourceLang] ?? capture.sourceLang]
                  .join(' · '),
              color: light1,
              trailing: TextButton(
                onPressed: () => _isReceipt(context),
                child: Text('영수증이에요',
                    style: body(12, color: textOn(light1)).copyWith(decoration: TextDecoration.underline)),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SerifTitle(_title, size: 32),
                  HoldPhoto(capture: capture),
                  for (final b in capture.blocks)
                    BandRow(
                      padding: const EdgeInsets.only(left: 24),
                      minHeight: 68,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(b.translated, style: serif(17)),
                                    const SizedBox(height: 3),
                                    Text(b.source, style: body(12, color: C.sub)),
                                  ],
                                ),
                              ),
                            ),
                            ListenCell(
                              tooltip: '현지어로 듣기',
                              onTap: () => _listen(context, b.source),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            ActionBand(
              label: '답장 카드 만들기',
              color: dark1,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReplyScreen(store: store, lang: capture.sourceLang, color: light1),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square confirm dialog in the app's style.
Future<bool?> confirm(BuildContext context, String title, String message, {String yes = '지우기'}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.ivory,
      surfaceTintColor: C.ivory,
      shape: const RoundedRectangleBorder(),
      title: Text(title, style: serif(20)),
      content: Text(message, style: body(14, color: C.sub)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: body(14, color: C.sub))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes, style: body(14, weight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
