import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart' show ink, muted;
import '../demo.dart';
import '../models.dart';
import '../store.dart';
import '../translator_service.dart';
import 'result_screen.dart';

/// S02 카메라 홈. Prototype: uses the system camera through image_picker.
class CameraHome extends StatefulWidget {
  final AppStore store;
  const CameraHome({super.key, required this.store});

  @override
  State<CameraHome> createState() => _CameraHomeState();
}

class _CameraHomeState extends State<CameraHome> {
  final _picker = ImagePicker();
  final _service = TranslatorService();
  String? _step;

  @override
  void initState() {
    super.initState();
    if (widget.store.loadFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toast(
          '저장된 기록을 읽지 못했어요. 원래 파일은 따로 보관해 뒀어요.'));
    }
    if (widget.store.logConsent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askLogConsent());
    }
  }

  String get _targetLang {
    final chosen = widget.store.targetLang;
    if (chosen != null) return chosen;
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code.isEmpty ? 'ko' : code;
  }

  int _demoIndex = 0;

  /// Web preview: no camera or ML Kit in the browser, so walk through the
  /// same flow with a sample photo. The Chinese sample comes first to show
  /// the "new trip" question.
  Future<(String, TranslationOutput)> _demoRun() async {
    final order = [
      ...demoSamples.where((s) => s.lang != 'ja'),
      ...demoSamples.where((s) => s.lang == 'ja'),
    ];
    final s = order[_demoIndex++ % order.length];
    for (final step in ['글자 읽는 중', '번역 중']) {
      if (mounted) setState(() => _step = step);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    return (s.asset, TranslationOutput(s.lang, s.blocks));
  }

  Future<void> _start(ImageSource source) async {
    widget.store.track('capture_started', {'source': source.name});
    try {
      final String imagePath;
      final TranslationOutput out;
      if (kIsWeb) {
        (imagePath, out) = await _demoRun();
      } else {
        final XFile? file = await _picker.pickImage(
          source: source,
          imageQuality: 90,
          maxWidth: 2400,
        );
        if (file == null || !mounted) return;
        imagePath = file.path;
        setState(() => _step = '글자 읽는 중');
        out = await _service.run(
          imagePath: file.path,
          scriptKey: widget.store.scriptKey,
          targetLang: _targetLang,
          onStep: (s) {
            if (mounted) setState(() => _step = s);
          },
        );
      }
      if (!mounted) return;

      final now = DateTime.now();
      var trip = widget.store.currentTrip;
      if (widget.store.needsNewTrip(out.sourceLang, now)) {
        setState(() => _step = null);
        final answer = await _askNewTrip(out.sourceLang);
        if (!mounted) return;
        widget.store.track('new_trip_answer', {'answer': answer == null ? 'continue' : 'new'});
        if (answer != null) {
          trip = await widget.store.createTrip(
            country: answer.$1,
            city: answer.$2,
            lang: out.sourceLang,
            now: now,
          );
        } else if (trip != null) {
          await widget.store.addLang(trip, out.sourceLang);
        }
      }
      trip ??= await widget.store.createTrip(
        country: guessCountry(out.sourceLang),
        city: '',
        lang: out.sourceLang,
        now: now,
      );

      final capture = await widget.store.addCapture(
        trip: trip,
        originalImagePath: imagePath,
        sourceLang: out.sourceLang,
        blocks: out.blocks,
        now: now,
      );
      if (!mounted) return;
      setState(() => _step = null);
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(store: widget.store, capture: capture),
      ));
    } on NoTextFound {
      widget.store.track('translate_failed', {'reason': 'no_text'});
      _toast('글자를 찾지 못했어요. 글자가 크게 보이게 다시 찍어주세요.');
    } on ModelDownloadFailed {
      widget.store.track('translate_failed', {'reason': 'model_download'});
      _toast('번역 언어팩을 내려받지 못했어요. 인터넷 연결을 확인해주세요.');
    } on UnsupportedLanguage catch (e) {
      widget.store.track('translate_failed', {'reason': 'unsupported', 'lang': e.code});
      _toast('아직 번역할 수 없는 언어예요 (${e.code}).');
    } catch (e) {
      widget.store.track('translate_failed', {'reason': 'other'});
      _toast('번역하지 못했어요. 다시 시도해주세요.');
      debugPrint('CamTrip error: $e');
    } finally {
      if (mounted) setState(() => _step = null);
    }
  }

  Future<void> _askLogConsent() async {
    if (!mounted) return;
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('앱 개선을 도와주실래요?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        content: const Text(
          '어떤 버튼을 눌렀는지, 번역이 됐는지 같은 사용 기록만 남겨요. '
          '사진·메모·번역 내용은 남기지 않아요.\n\n'
          '지금은 이 폰 안에만 저장되고, 설정에서 언제든 끄거나 지울 수 있어요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('남기지 않기', style: TextStyle(color: muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('남기기', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    await widget.store.setLogConsent(agreed ?? false);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Returns (country, city) or null when the user keeps the current trip.
  Future<(String, String)?> _askNewTrip(String lang) async {
    final hasTrip = widget.store.currentTrip != null;
    final country = TextEditingController(text: guessCountry(lang));
    final city = TextEditingController();
    final result = await showDialog<(String, String)?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('새 여행인가요?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: country,
              decoration: const InputDecoration(labelText: '나라'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: '도시 (예: 도쿄)'),
            ),
          ],
        ),
        actions: [
          if (hasTrip)
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('지금 여행에 이어서', style: TextStyle(color: muted)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, (country.text.trim(), city.text.trim())),
            child: const Text('새 여행 시작', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    // Dispose after the dialog route has fully closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      country.dispose();
      city.dispose();
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final trip = widget.store.currentTrip;
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip == null ? '아직 여행이 없어요' : trip.name.toUpperCase(),
                    style: const TextStyle(fontSize: 12, letterSpacing: 1, color: muted),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '읽지 못한 글자를\n찍어보세요',
                    style: TextStyle(fontSize: 30, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.8),
                  ),
                  const SizedBox(height: 24),
                  const Text('글자 종류', style: TextStyle(fontSize: 13, color: muted)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 18,
                    children: [
                      for (final e in scriptOptions.entries)
                        _ScriptChip(
                          label: e.value,
                          selected: widget.store.scriptKey == e.key,
                          onTap: () => widget.store.setScript(e.key),
                        ),
                    ],
                  ),
                  const Spacer(),
                  const Divider(),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _step == null ? () => _start(ImageSource.camera) : null,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('찍어서 번역', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _step == null ? () => _start(ImageSource.gallery) : null,
                    child: const Text('갤러리에서 고르기'),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      kIsWeb
                          ? '웹 미리보기: 샘플 사진으로 흐름만 보여줘요'
                          : '시제품: 글자 인식과 번역은 모두 이 폰 안에서 해요',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                ],
              ),
            ),
            if (_step != null)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.92),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ink),
                      ),
                      const SizedBox(height: 16),
                      Text(_step!, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ScriptChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ScriptChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          widthFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? ink : muted,
              decoration: selected ? TextDecoration.underline : TextDecoration.none,
              decorationColor: ink,
            ),
          ),
        ),
      ),
    );
  }
}
