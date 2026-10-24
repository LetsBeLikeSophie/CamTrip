import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show ink, muted;
import '../store.dart';
import '../translator_service.dart';

/// 설정. Prototype: only the language to translate into.
class SettingsScreen extends StatelessWidget {
  final AppStore store;
  const SettingsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final phone = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        final phoneName = targetOptions[phone] ?? phone;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Text(
              '설정',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5),
            ),
            const SizedBox(height: 24),
            const Text('번역할 언어', style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(height: 4),
            _option('폰 언어 따라가기 ($phoneName)', store.targetLang == null, () => store.setTargetLang(null)),
            for (final e in targetOptions.entries)
              _option(e.value, store.targetLang == e.key, () => store.setTargetLang(e.key)),
            if (!kIsWeb) ...[
              const SizedBox(height: 24),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: ink,
                title: const Text('사용 기록 남기기', style: TextStyle(fontSize: 15)),
                subtitle: const Text(
                  '앱 개선용. 누른 버튼과 번역 성공 여부만 남기고 사진·메모·번역 내용은 남기지 않아요. 지금은 이 폰 안에만 있어요.',
                  style: TextStyle(fontSize: 12, color: muted, height: 1.5),
                ),
                value: store.logConsent == true,
                onChanged: (v) => store.setLogConsent(v),
              ),
              if (store.logConsent == true)
                Row(
                  children: [
                    Expanded(
                      child: Text('기록 ${store.usage.lines.length}개', style: const TextStyle(fontSize: 13, color: muted)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: store.usage.lines.join('\n')));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('사용 기록을 복사했어요')),
                          );
                        }
                      },
                      child: const Text('복사', style: TextStyle(color: ink)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await store.usage.clear();
                        store.setLogConsent(true);
                      },
                      child: const Text('지우기', style: TextStyle(color: muted)),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              '여행 ${store.trips.length}개 · 번역 ${store.captures.length}개\n'
              '모든 기록과 사진은 이 폰 안에만 저장돼요.',
              style: const TextStyle(fontSize: 13, color: muted, height: 1.5),
            ),
          ],
        );
      },
    );
  }

  Widget _option(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? ink : muted,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check, size: 18, color: ink),
          ],
        ),
      ),
    );
  }
}
