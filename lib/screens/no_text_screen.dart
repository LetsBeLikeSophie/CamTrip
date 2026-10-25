import 'package:flutter/material.dart';

import '../models.dart';
import '../photo.dart';
import '../ui.dart';

/// Shown when a photo has no text the phone can read. Pops with 'retake'.
class NoTextScreen extends StatelessWidget {
  final String imagePath;
  final TripPalette palette;
  const NoTextScreen({super.key, required this.imagePath, required this.palette});

  @override
  Widget build(BuildContext context) {
    final light2 = Color(palette.light2);
    final dark1 = Color(palette.dark1);
    Widget tip(String n, String text) => BandRow(
          child: Row(
            children: [
              SizedBox(width: 40, child: Text(n, style: mono(11))),
              Expanded(child: Text(text, style: body(15))),
            ],
          ),
        );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TopBar(
              actions: [
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: C.navy),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ColoredBox(
                    color: C.photoDark,
                    child: SizedBox(
                      height: 220,
                      child: imagePath.isEmpty ? null : capturePhoto(imagePath, fit: BoxFit.contain, cacheWidth: 900),
                    ),
                  ),
                  BandRow(color: light2, child: Text('글자를 찾지 못했어요', style: body(14, weight: FontWeight.w500, color: textOn(light2)))),
                  const SerifTitle('다시 찍어볼까요?', size: 30),
                  Container(height: 1, color: C.navy),
                  tip('01', '글자가 화면을 가득 채우게'),
                  tip('02', '빛 반사가 없게, 흔들리지 않게'),
                  tip('03', '손글씨는 잘 못 읽어요'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                    child: Text('손글씨는 곧 "현지인에게 물어보기"와 "AI로 읽기"로 도와드릴게요.', style: body(12, color: C.sub)),
                  ),
                ],
              ),
            ),
            ActionBand(label: '다시 찍기', color: dark1, onTap: () => Navigator.pop(context, 'retake')),
          ],
        ),
      ),
    );
  }
}
