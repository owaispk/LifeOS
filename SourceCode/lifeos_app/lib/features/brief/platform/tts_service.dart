// Text-to-speech service (PBI-039a).
import 'package:flutter_tts/flutter_tts.dart';

/// TTS rate constraints.
const ttsRateMin = 0.5;
const ttsRateMax = 1.5;

/// Configuration for TTS initialization.
class TtsConfig {
  const TtsConfig({
    this.rate = 0.85,  // Default slower rate for better clarity
    this.language = 'en-US',
  });

  /// Speech rate (0.5–1.5).
  final double rate;

  /// Language code (e.g., 'en-US' or 'ur-PK').
  final String language;
}

/// Returns the TTS language code for the app language.
String ttsLanguageFor(String appLanguage) {
  switch (appLanguage) {
    case 'ur':
      return 'ur-PK';
    default:
      return 'en-US';
  }
}

/// Text-to-speech service wrapping flutter_tts.
class TtsService {
  TtsService();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  double _rate = 1.0;
  String _language = 'en-US';

  /// Called when speech completes.
  void Function()? onComplete;

  /// Called when speech is cancelled.
  void Function()? onCancel;

  /// Initialize TTS with the given configuration.
  Future<void> init(TtsConfig config) async {
    _rate = config.rate.clamp(ttsRateMin, ttsRateMax);
    _language = config.language;

    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_rate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      onComplete?.call();
    });

    _tts.setCancelHandler(() {
      onCancel?.call();
    });

    _initialized = true;
  }

  /// Set speech rate (0.5 to 1.5, default 1.0).
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(ttsRateMin, ttsRateMax);
    await _tts.setSpeechRate(_rate);
  }

  /// Set language (en-US or ur-PK).
  Future<void> setLanguage(String language) async {
    _language = language;
    await _tts.setLanguage(language);
  }

  /// Speak the text.
  Future<void> speak(String text) async {
    if (!_initialized) {
      await init(TtsConfig(rate: _rate, language: _language));
    }
    await _tts.speak(text);
  }

  /// Stop speaking.
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Check if TTS is available.
  Future<bool> isAvailable() async {
    try {
      final languages = await _tts.getLanguages;
      return languages.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Check if Urdu is supported.
  Future<bool> isUrduSupported() async {
    try {
      final languages = await _tts.getLanguages as List<dynamic>;
      return languages.any((l) => l.toString().startsWith('ur'));
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _tts.stop();
  }
}
