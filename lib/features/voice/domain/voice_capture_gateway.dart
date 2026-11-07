enum VoiceCaptureStatus { idle, listening, error }

final class VoiceTranscript {
  const VoiceTranscript({
    required this.text,
    required this.isFinal,
  });

  final String text;
  final bool isFinal;
}

abstract class VoiceCaptureGateway {
  Future<bool> ensureReady();

  Future<void> start({
    required void Function(VoiceTranscript transcript) onTranscript,
    required void Function(String message) onError,
    required void Function() onDone,
    void Function()? onStarted,
    void Function(double level)? onSoundLevel,
  });

  Future<void> stop();

  Future<void> cancel();
}
