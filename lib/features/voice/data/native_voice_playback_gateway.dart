import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/voice/domain/voice_playback_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TextToSpeech / AVSpeechSynthesizer del sistema.
class NativeVoicePlaybackGateway implements VoicePlaybackGateway {
  NativeVoicePlaybackGateway({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1);
    await _tts.setPitch(1);
    // Más despacio: usuario con visión reducida / mayor.
    await _tts.setSpeechRate(0.42);
    final language = await _spanishLanguage();
    if (language != null) {
      await _tts.setLanguage(language);
    }
    _ready = true;
  }

  Future<String?> _spanishLanguage() async {
    final raw = await _tts.getLanguages;
    if (raw is! List) return 'es-MX';
    final languages = raw.map((item) => item.toString()).toList();
    const preferred = ['es-CO', 'es-MX', 'es-ES', 'es-US', 'es-AR'];
    for (final id in preferred) {
      if (_hasLanguage(languages, id)) return _match(languages, id) ?? id;
    }
    for (final language in languages) {
      final normalized = language.toLowerCase().replaceAll('_', '-');
      if (normalized == 'es' || normalized.startsWith('es-')) {
        return language;
      }
    }
    return languages.isEmpty ? 'es-MX' : null;
  }

  bool _hasLanguage(List<String> languages, String wanted) {
    return _match(languages, wanted) != null;
  }

  String? _match(List<String> languages, String wanted) {
    final needle = wanted.toLowerCase().replaceAll('_', '-');
    for (final language in languages) {
      if (language.toLowerCase().replaceAll('_', '-') == needle) {
        return language;
      }
    }
    return null;
  }

  @override
  Future<void> speak(String text) async {
    final clean = InputSanitizer.spokenText(text);
    if (clean.isEmpty) return;
    await stop();
    await _ensureReady();
    await _tts.speak(clean);
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (error) {
      debugPrint('DaleU TTS stop failed: $error');
    }
  }
}
