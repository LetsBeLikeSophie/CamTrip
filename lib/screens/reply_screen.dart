import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../store.dart';
import '../translator_service.dart';
import '../ui.dart';
import '../voice.dart';
import 'translate_screen.dart' show langNames;

const _phrases = ['이거 하나 주세요', '고수 빼주세요', '덜 맵게 해주세요', '포장 되나요?', '카드 되나요?'];

/// Web preview only: the browser cannot run on-device translation.
const _demoJa = {
  '이거 하나 주세요': 'これをひとつください',
  '고수 빼주세요': 'パクチー抜きでお願いします',
  '덜 맵게 해주세요': '辛さ控えめでお願いします',
  '포장 되나요?': '持ち帰りできますか？',
  '카드 되나요?': 'カードは使えますか？',
};

/// Write what you want to say; it is shown big in the local language.
class ReplyScreen extends StatefulWidget {
  final AppStore store;
  final String lang;
  final Color color;
  const ReplyScreen({super.key, required this.store, required this.lang, required this.color});

  @override
  State<ReplyScreen> createState() => _ReplyScreenState();
}

class _ReplyScreenState extends State<ReplyScreen> {
  final _input = TextEditingController(text: _phrases[1]);
  final _service = TranslatorService();
  String _local = '';
  bool _busy = false;
  Timer? _debounce;

  String get _userLang {
    final chosen = widget.store.targetLang;
    if (chosen != null) return chosen;
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code.isEmpty ? 'ko' : code;
  }

  @override
  void initState() {
    super.initState();
    _translate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _translate);
  }

  Future<void> _translate() async {
    final text = _input.text.trim();
    if (text.isEmpty) {
      setState(() => _local = '');
      return;
    }
    if (kIsWeb) {
      setState(() => _local = _demoJa[text] ?? '（웹 미리보기에서는 예시 문장만 바뀌어요）');
      return;
    }
    setState(() => _busy = true);
    try {
      final out = await _service.translateText(text, from: _userLang, to: widget.lang);
      if (mounted && _input.text.trim() == text) setState(() => _local = out);
    } catch (e) {
      if (mounted) toast(context, '번역하지 못했어요. 처음이면 인터넷 연결이 필요해요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pick(String phrase) {
    _input.text = phrase;
    widget.store.track('reply_phrase_picked');
    _translate();
  }

  Future<void> _say() async {
    if (_local.isEmpty) return;
    final ok = await Speaker.instance.say(_local, widget.lang);
    if (!ok && mounted) toast(context, '이 폰에 ${langNames[widget.lang] ?? '이 언어'} 음성이 없어요.');
  }

  void _showBig() {
    if (_local.isEmpty) return;
    widget.store.track('reply_card_shown');
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _BigCard(local: _local, mine: _input.text.trim(), color: widget.color, onSay: _say),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fg = textOn(widget.color);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TopBar(leading: BackArrow()),
            ContextBand(label: '${langNames[widget.lang] ?? widget.lang}로 보여줘요', color: widget.color),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SerifTitle('답장 카드', size: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: _input,
                      onChanged: _changed,
                      style: body(16),
                      decoration: InputDecoration(
                        labelText: '하고 싶은 말',
                        labelStyle: body(13, color: C.sub),
                        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                        enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.navy)),
                        focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.navy, width: 1.5)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                    child: Wrap(
                      spacing: 16,
                      children: [
                        for (final p in _phrases)
                          InkWell(
                            onTap: () => _pick(p),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Align(
                                widthFactor: 1,
                                child: Text(
                                  p,
                                  style: body(13,
                                          weight: _input.text == p ? FontWeight.w600 : FontWeight.w400,
                                          color: _input.text == p ? C.navy : C.sub)
                                      .copyWith(decoration: _input.text == p ? TextDecoration.underline : null),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    color: widget.color,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 22, 16, 22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_busy ? '번역 중…' : _local,
                                      style: body(26, weight: FontWeight.w600, color: fg, height: 1.4)),
                                  const SizedBox(height: 8),
                                  Text(_input.text, style: body(13, color: fg.withValues(alpha: 0.75))),
                                ],
                              ),
                            ),
                          ),
                          ListenCell(tooltip: '현지어로 읽어주기', onTap: _say),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ActionBand(label: '크게 보여주기', color: C.navy, onTap: _local.isEmpty ? null : _showBig),
          ],
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final String local;
  final String mine;
  final Color color;
  final VoidCallback onSay;
  const _BigCard({required this.local, required this.mine, required this.color, required this.onSay});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
            ContextBand(label: '점원에게 보여주세요', color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(local, style: body(40, weight: FontWeight.w600, height: 1.35)),
                    const SizedBox(height: 16),
                    Text(mine, style: body(15, color: C.sub)),
                  ],
                ),
              ),
            ),
            ActionBand(label: '소리로 들려주기', icon: Icons.volume_up_outlined, color: C.navy, onTap: onSay),
          ],
        ),
      ),
    );
  }
}
