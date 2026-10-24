import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'models.dart';

const _scripts = ['japanese', 'chinese', 'korean', 'latin'];

TextRecognitionScript _script(String key) {
  switch (key) {
    case 'chinese':
      return TextRecognitionScript.chinese;
    case 'korean':
      return TextRecognitionScript.korean;
    case 'latin':
      return TextRecognitionScript.latin;
    case 'japanese':
    default:
      return TextRecognitionScript.japanese;
  }
}

/// Recognition script that suits a language.
String scriptFor(String lang) {
  switch (lang) {
    case 'zh':
      return 'chinese';
    case 'ko':
      return 'korean';
    case 'ja':
      return 'japanese';
    default:
      return 'latin';
  }
}

final _kana = RegExp(r'[぀-ヿ]');
final _hangul = RegExp(r'[가-힣]');
final _han = RegExp(r'[一-鿿]');

/// Decides the source language from what the language detector said and
/// the characters themselves. Kana means Japanese, hangul means Korean.
/// Kanji-only signs are often detected as Chinese, so on a Japanese trip
/// they stay Japanese.
String decideLang(String identified, String text, {String? tripLang}) {
  var lang = identified.contains('-') ? identified.split('-').first : identified;
  if (_kana.hasMatch(text)) return 'ja';
  if (_hangul.hasMatch(text)) return 'ko';
  if (_han.hasMatch(text)) {
    if (tripLang == 'ja' || tripLang == 'zh') return tripLang!;
    return lang == 'ja' ? 'ja' : 'zh';
  }
  if (lang == 'und' || lang.isEmpty) return tripLang ?? 'en';
  return lang;
}

TranslateLanguage? _translateLang(String code) {
  for (final l in TranslateLanguage.values) {
    if (l.bcpCode == code) return l;
  }
  return null;
}

/// Languages the user can translate into (settings screen).
const targetOptions = <String, String>{
  'ko': '한국어',
  'en': '영어',
  'ja': '일본어',
  'zh': '중국어',
};

class TranslationOutput {
  final String sourceLang;
  final String scriptKey;
  final List<TextBlockResult> blocks;
  const TranslationOutput(this.sourceLang, this.scriptKey, this.blocks);
}

class NoTextFound implements Exception {}

class ModelDownloadFailed implements Exception {}

class UnsupportedLanguage implements Exception {
  final String code;
  UnsupportedLanguage(this.code);
}

/// Everything runs on the device: text recognition → language id →
/// on-device translation. The first use of a language downloads its model
/// (about 30 MB) once.
class TranslatorService {
  Future<RecognizedText> _recognize(String imagePath, String scriptKey) async {
    final recognizer = TextRecognizer(script: _script(scriptKey));
    try {
      return await recognizer.processImage(InputImage.fromFilePath(imagePath));
    } finally {
      await recognizer.close();
    }
  }

  int _chars(RecognizedText r) => r.text.replaceAll(RegExp(r'\s'), '').length;

  /// Tries the most likely script first and only reads again with the
  /// others when it found (almost) nothing, so nobody has to pick a script.
  Future<(RecognizedText, String)> _recognizeAuto(String imagePath, String hint) async {
    var bestKey = hint;
    var best = await _recognize(imagePath, hint);
    if (_chars(best) >= 6) return (best, bestKey);
    for (final key in _scripts.where((k) => k != hint)) {
      final r = await _recognize(imagePath, key);
      if (_chars(r) > _chars(best)) {
        best = r;
        bestKey = key;
      }
      if (_chars(best) >= 6) break;
    }
    return (best, bestKey);
  }

  Future<String> _identify(String text) async {
    final identifier = LanguageIdentifier(confidenceThreshold: 0.4);
    try {
      return await identifier.identifyLanguage(text);
    } finally {
      await identifier.close();
    }
  }

  Future<void> _ensureModels(List<TranslateLanguage> langs, void Function(String step)? onStep) async {
    final manager = OnDeviceTranslatorModelManager();
    for (final l in langs) {
      if (!await manager.isModelDownloaded(l.bcpCode)) {
        onStep?.call('번역 언어팩 내려받는 중 (처음 한 번)');
        final ok = await manager.downloadModel(l.bcpCode, isWifiRequired: false);
        if (!ok) throw ModelDownloadFailed();
      }
    }
  }

  Future<TranslationOutput> run({
    required String imagePath,
    required String scriptHint,
    required String targetLang,
    String? tripLang,
    void Function(String step)? onStep,
  }) async {
    onStep?.call('글자 읽는 중');
    var (recognized, scriptKey) = await _recognizeAuto(imagePath, scriptHint);
    if (recognized.blocks.every((b) => b.text.trim().isEmpty)) throw NoTextFound();

    final lang = decideLang(await _identify(recognized.text), recognized.text, tripLang: tripLang);
    // Read again with the script that fits the language, when different.
    final fitting = scriptFor(lang);
    if (fitting != scriptKey) {
      final again = await _recognize(imagePath, fitting);
      if (_chars(again) >= _chars(recognized)) {
        recognized = again;
        scriptKey = fitting;
      }
    }
    final textBlocks = recognized.blocks.where((b) => b.text.trim().isNotEmpty).toList();
    if (textBlocks.isEmpty) throw NoTextFound();

    final source = _translateLang(lang);
    final target = _translateLang(targetLang) ?? TranslateLanguage.korean;
    if (source == null) throw UnsupportedLanguage(lang);

    TextBlockResult block(TextBlock b, String translated) => TextBlockResult(
          left: b.boundingBox.left,
          top: b.boundingBox.top,
          width: b.boundingBox.width,
          height: b.boundingBox.height,
          source: b.text,
          translated: translated,
        );

    if (source == target) {
      return TranslationOutput(lang, scriptKey, [for (final b in textBlocks) block(b, b.text)]);
    }

    await _ensureModels([source, target], onStep);
    onStep?.call('번역 중');
    final translator = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    final results = <TextBlockResult>[];
    try {
      for (final b in textBlocks) {
        results.add(block(b, await translator.translateText(b.text)));
      }
    } finally {
      await translator.close();
    }
    return TranslationOutput(lang, scriptKey, results);
  }

  /// Plain text translation, used for reply cards (user language → local).
  Future<String> translateText(String text, {required String from, required String to}) async {
    final source = _translateLang(from);
    final target = _translateLang(to);
    if (source == null) throw UnsupportedLanguage(from);
    if (target == null) throw UnsupportedLanguage(to);
    if (source == target) return text;
    await _ensureModels([source, target], null);
    final translator = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    try {
      return await translator.translateText(text);
    } finally {
      await translator.close();
    }
  }
}
