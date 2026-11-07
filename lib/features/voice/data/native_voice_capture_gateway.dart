import 'package:dale_u/features/voice/domain/voice_capture_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// SpeechRecognizer nativo del teléfono. Sin APIs nuestras.
class NativeVoiceCaptureGateway implements VoiceCaptureGateway {
  NativeVoiceCaptureGateway({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _ready = false;

  void Function(VoiceTranscript transcript)? _onTranscript;
  void Function(String message)? _onError;
  void Function()? _onDone;
  void Function()? _onStarted;
  void Function(double level)? _onSoundLevel;

  @override
  Future<bool> ensureReady() async {
    final mic = await Permission.microphone.request();
    if (mic.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    if (!mic.isGranted) return false;

    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        debugLogging: kDebugMode,
        options: [SpeechToText.androidNoBluetooth],
        onError: (error) {
          debugPrint('DaleU STT error: ${error.errorMsg}');
          _onError?.call(_mapError(error.errorMsg));
          _onDone?.call();
        },
        onStatus: (status) {
          debugPrint('DaleU STT status: $status');
          if (status == SpeechToText.listeningStatus) {
            _onStarted?.call();
          }
          if (status == SpeechToText.doneStatus) {
            _onDone?.call();
          }
        },
      );
    } on PlatformException catch (error) {
      debugPrint('DaleU STT init failed: ${error.code} ${error.message}');
      _ready = false;
    } catch (error) {
      debugPrint('DaleU STT init failed: $error');
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<void> start({
    required void Function(VoiceTranscript transcript) onTranscript,
    required void Function(String message) onError,
    required void Function() onDone,
    void Function()? onStarted,
    void Function(double level)? onSoundLevel,
  }) async {
    _onTranscript = onTranscript;
    _onError = onError;
    _onDone = onDone;
    _onStarted = onStarted;
    _onSoundLevel = onSoundLevel;

    final ready = await ensureReady();
    if (!ready) {
      final status = await Permission.microphone.status;
      if (status.isPermanentlyDenied) {
        onError(
          'El micrófono está bloqueado. En Ajustes de Dale U, permite Micrófono y vuelve a pulsar Hablar.',
        );
      } else if (!status.isGranted) {
        onError('Dale U necesita el micrófono. Pulsa Hablar y acepta el permiso.');
      } else {
        onError('No se pudo iniciar la voz del teléfono. Inténtalo de nuevo.');
      }
      onDone();
      return;
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.trim();
          if (text.isEmpty) return;
          _onTranscript?.call(
            VoiceTranscript(text: text, isFinal: result.finalResult),
          );
        },
        onSoundLevelChange: (level) {
          _onSoundLevel?.call(level);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          onDevice: false,
          listenMode: ListenMode.confirmation,
          listenFor: const Duration(seconds: 30),
        ),
      );
      onStarted?.call();
    } catch (error) {
      debugPrint('DaleU STT listen failed: $error');
      onError('No se pudo iniciar el micrófono.');
      onDone();
    }
  }

  String _mapError(String code) {
    if (code.contains('error_permission') || code.contains('permission')) {
      return 'Sin permiso de micrófono. Actívalo para hablar.';
    }
    if (code.contains('error_language')) {
      return 'Este teléfono no tiene español para voz. En Ajustes, idioma de voz, descarga Español.';
    }
    if (code.contains('error_network')) {
      return 'Hace falta internet la primera vez que el teléfono usa la voz.';
    }
    if (code.contains('error_speech_timeout') ||
        code.contains('error_no_match') ||
        code.contains('error_client')) {
      return 'No se escuchó nada. Pulsa Hablar, espera el pitido y habla cerca del teléfono.';
    }
    return 'No se entendió. Inténtalo de nuevo.';
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
