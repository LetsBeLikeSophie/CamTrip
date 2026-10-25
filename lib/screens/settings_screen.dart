import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store.dart';
import '../translator_service.dart';
import '../ui.dart';

class SettingsScreen extends StatelessWidget {
  final AppStore store;
  const SettingsScreen({super.key, required this.store});

  Widget _section(String label, Color color) => Container(
        color: color,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerLeft,
        child: Text(label, style: mono(11, color: textOn(color))),
      );

  Widget _choice(String label, bool selected, VoidCallback onTap) => BandRow(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: body(15, weight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? C.navy : C.sub)),
            ),
            if (selected) const Icon(Icons.check, size: 18, color: C.navy),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final trip = store.currentTrip;
        final light1 = trip?.light1 ?? const Color(0xFFD6DDF0);
        final light2 = trip?.light2 ?? const Color(0xFFEBDCE8);
        final phone = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const TopBar(leading: BackArrow()),
                const SerifTitle('설정', size: 36),
                _section('번역할 언어', light1),
                _choice('폰 언어 따라가기 (${targetOptions[phone] ?? phone})', store.targetLang == null,
                    () => store.setTargetLang(null)),
                for (final e in targetOptions.entries)
                  _choice(e.value, store.targetLang == e.key, () => store.setTargetLang(e.key)),
                if (!kIsWeb) ...[
                  _section('저녁 정리', light1),
                  BandRow(
                    child: Row(
                      children: [
                        Expanded(child: Text('정리 알림', style: body(15))),
                        Checkbox(
                          value: store.reminderOn,
                          activeColor: C.navy,
                          shape: const RoundedRectangleBorder(),
                          onChanged: (v) => store.setReminder(on: v ?? false),
                        ),
                      ],
                    ),
                  ),
                  BandRow(
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: store.reminderHour, minute: store.reminderMinute),
                      );
                      if (t != null) await store.setReminder(hour: t.hour, minute: t.minute);
                    },
                    child: Row(
                      children: [
                        Expanded(child: Text('알림 시간', style: body(15))),
                        Text(
                          '${store.reminderHour.toString().padLeft(2, '0')}:${store.reminderMinute.toString().padLeft(2, '0')}',
                          style: mono(14, color: C.navy),
                        ),
                      ],
                    ),
                  ),
                  _section('개인정보', light1),
                  BandRow(
                    minHeight: 72,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('사용 기록 남기기', style: body(15)),
                              Text('누른 버튼과 번역 성공 여부만. 사진·메모·번역 내용은 안 남겨요. 지금은 이 폰 안에만 있어요.',
                                  style: body(12, color: C.sub)),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: store.logConsent == true,
                          activeColor: C.navy,
                          shape: const RoundedRectangleBorder(),
                          onChanged: (v) => store.setLogConsent(v ?? false),
                        ),
                      ],
                    ),
                  ),
                  if (store.logConsent == true)
                    BandRow(
                      child: Row(
                        children: [
                          Expanded(child: Text('기록 ${store.usage.lines.length}개', style: body(13, color: C.sub))),
                          TextButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: store.usage.lines.join('\n')));
                              if (context.mounted) toast(context, '사용 기록을 복사했어요');
                            },
                            child: Text('복사', style: body(14)),
                          ),
                          TextButton(
                            onPressed: () async {
                              await store.usage.clear();
                              await store.setLogConsent(true);
                            },
                            child: Text('지우기', style: body(14, color: C.sub)),
                          ),
                        ],
                      ),
                    ),
                ],
                BandRow(
                  color: light2,
                  minHeight: 72,
                  child: Text(
                    '사진은 폰 밖으로 나가지 않아요. 글자 읽기, 번역, 말로 남긴 메모를 글자로 바꾸는 것까지 모두 이 폰 안에서 해요.',
                    style: body(13, color: textOn(light2), height: 1.6),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Text(
                    '여행 ${store.trips.length}개 · 기록 ${store.captures.length + store.memos.length}개\nCAMTRIP 0.2.0',
                    style: mono(11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
