import 'package:flutter/material.dart';

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
