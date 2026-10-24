import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../ui.dart';

/// First run: what the app does, and the optional usage-log consent.
class WelcomeScreen extends StatefulWidget {
  final AppStore store;
  const WelcomeScreen({super.key, required this.store});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _logs = false;

  @override
  Widget build(BuildContext context) {
    final light1 = Color(TripPalette.fallback.light1);
    final light2 = Color(TripPalette.fallback.light2);
    Widget step(String n, String title, String sub) => BandRow(
          minHeight: 68,
          child: Row(
            children: [
              SizedBox(width: 40, child: Text(n, style: mono(11))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: body(15, weight: FontWeight.w600)),
                    Text(sub, style: body(13, color: C.sub)),
                  ],
                ),
              ),
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
              leading: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text('CamTrip', style: serif(20, weight: FontWeight.w600)),
              ),
            ),
            ContextBand(label: '처음 오셨어요 · 1분이면 돼요', color: light1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SerifTitle('찍고, 말하면\n여행기가 돼요.', size: 36),
                  Container(height: 1, color: C.navy),
                  step('01', '메뉴·간판을 찍으면', '바로 한국어로 보여주고 읽어줘요'),
                  step('02', '영수증을 찍거나 말로 남기면', '경비가 알아서 쌓여요'),
                  step('03', '날마다 기록이 모이면', '하루하루가 여행기가 돼요'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Text('사진은 폰 밖으로 나가지 않아요. 카메라와 마이크는 처음 쓸 때 한 번씩 물어볼게요.',
                        style: body(13, color: C.sub, height: 1.6)),
                  ),
                  Material(
                    color: light2,
                    child: InkWell(
                      onTap: () => setState(() => _logs = !_logs),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 24, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _logs,
                              activeColor: C.navy,
                              shape: const RoundedRectangleBorder(),
                              onChanged: (v) => setState(() => _logs = v ?? false),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('사용 기록을 남겨 앱 개선 돕기 (선택)', style: body(14, weight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text('누른 버튼과 번역 성공 여부만 남겨요. 사진·메모·번역 내용은 남기지 않아요. 설정에서 언제든 끌 수 있어요.',
                                        style: body(12, color: C.sub)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ActionBand(
              label: '시작하기',
              color: C.navy,
              onTap: () => widget.store.finishOnboarding(logs: _logs),
            ),
          ],
        ),
      ),
    );
  }
}
