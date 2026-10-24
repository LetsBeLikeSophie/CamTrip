import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

const _ttsLocales = {
  'ja': 'ja-JP',
  'zh': 'zh-CN',
  'ko': 'ko-KR',
  'en': 'en-US',
  'fr': 'fr-FR',
  'de': 'de-DE',
  'es': 'es-ES',
  'it': 'it-IT',
  'vi': 'vi-VN',
};

/// Reads local words aloud with the phone's own voice (works offline when
/// the phone has that language's voice installed).
class Speaker {
  Speaker._();
  static final instance = Speaker._();
  final _tts = FlutterTts();

  /// False when the phone has no voice for [lang].
  Future<bool> say(String text, String lang) async {
    final locale = _ttsLocales[lang] ?? lang;
    try {
      final ok = await _tts.isLanguageAvailable(locale);
      if (ok == false) return false;
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
      await _tts.stop();
      await _tts.speak(text);
      return true;
    } catch (e) {
      debugPrint('CamTrip: speak failed: $e');
      return false;
    }
  }
}

/// Press-and-talk memos. Only the recognized text is kept, never audio.
class Mic {
  Mic._();
  static final instance = Mic._();
  final _stt = SpeechToText();
  bool _ready = false;

  Future<bool> _init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(onError: (e) => debugPrint('CamTrip: speech error: ${e.errorMsg}'));
    } catch (e) {
      debugPrint('CamTrip: speech init failed: $e');
      _ready = false;
    }
    return _ready;
  }

  /// Starts listening; [onText] gets the words so far. False when speech
  /// recognition is not available or the microphone was refused.
  Future<bool> start({required String localeId, required void Function(String text) onText}) async {
    if (!await _init()) return false;
    await _stt.listen(
      onResult: (r) => onText(r.recognizedWords),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return true;
  }

  Future<void> stop() async {
    if (_ready) await _stt.stop();
  }
}
