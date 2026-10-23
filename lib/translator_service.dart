import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'models.dart';

/// Scripts the user can pick on the camera screen.
const scriptOptions = <String, String>{
  'japanese': '일본어',
  'chinese': '중국어',
  'korean': '한국어',
  'latin': '영어·유럽어',
};

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

/// Fallback language when the language detector is unsure.
String _defaultLangFor(String scriptKey) {
  switch (scriptKey) {
    case 'chinese':
      return 'zh';
    case 'korean':
      return 'ko';
    case 'latin':
      return 'en';
    case 'japanese':
    default:
      return 'ja';
  }
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
  final List<TextBlockResult> blocks;
  const TranslationOutput(this.sourceLang, this.blocks);
}

class NoTextFound implements Exception {}

class ModelDownloadFailed implements Exception {}

class UnsupportedLanguage implements Exception {
  final String code;
  UnsupportedLanguage(this.code);
}

/// Prototype pipeline, entirely on the device:
/// text recognition → language id → on-device translation.
/// The first use of a language downloads its model (about 30 MB) once.
class TranslatorService {
  Future<RecognizedText> _recognize(String imagePath, String scriptKey) async {
    final recognizer = TextRecognizer(script: _script(scriptKey));
    try {
      return await recognizer.processImage(InputImage.fromFilePath(imagePath));
    } finally {
      await recognizer.close();
    }
  }

  Future<String> _identify(String text) async {
    final identifier = LanguageIdentifier(confidenceThreshold: 0.4);
    try {
      return await identifier.identifyLanguage(text);
    } finally {
      await identifier.close();
    }
  }

  Future<TranslationOutput> run({
    required String imagePath,
    required String scriptKey,
    required String targetLang,
    void Function(String step)? onStep,
  }) async {
    onStep?.call('글자 읽는 중');
    final recognized = await _recognize(imagePath, scriptKey);
    final textBlocks = recognized.blocks.where((b) => b.text.trim().isNotEmpty).toList();
    if (textBlocks.isEmpty) throw NoTextFound();

    var lang = await _identify(recognized.text);
    if (lang == 'und') lang = _defaultLangFor(scriptKey);
    // Chinese can come back as zh-Latn etc.
    if (lang.contains('-')) lang = lang.split('-').first;
    // Kanji-heavy Japanese signs are often detected as Chinese (and the
    // reverse). For CJK scripts, trust the script the user picked.
    const cjk = {'ja', 'zh', 'ko'};
    final picked = _defaultLangFor(scriptKey);
    if (cjk.contains(picked) && cjk.contains(lang) && lang != picked) {
      lang = picked;
    }

    final source = _translateLang(lang);
    final target = _translateLang(targetLang) ?? TranslateLanguage.korean;
    if (source == null) throw UnsupportedLanguage(lang);

    if (source == target) {
      return TranslationOutput(lang, [
        for (final b in textBlocks)
          TextBlockResult(
            left: b.boundingBox.left,
            top: b.boundingBox.top,
            width: b.boundingBox.width,
            height: b.boundingBox.height,
            source: b.text,
            translated: b.text,
          ),
      ]);
    }

    final manager = OnDeviceTranslatorModelManager();
    for (final code in [source.bcpCode, target.bcpCode]) {
      if (!await manager.isModelDownloaded(code)) {
        onStep?.call('번역 언어팩 내려받는 중 (처음 한 번)');
        final ok = await manager.downloadModel(code, isWifiRequired: false);
        if (!ok) throw ModelDownloadFailed();
      }
    }

    onStep?.call('번역 중');
    final translator = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    final results = <TextBlockResult>[];
    try {
      for (final b in textBlocks) {
        final out = await translator.translateText(b.text);
        results.add(TextBlockResult(
          left: b.boundingBox.left,
          top: b.boundingBox.top,
          width: b.boundingBox.width,
          height: b.boundingBox.height,
          source: b.text,
          translated: out,
        ));
      }
    } finally {
      await translator.close();
    }
    return TranslationOutput(lang, results);
  }
}
