/// Sintetizador nativo del teléfono (TextToSpeech / AVSpeech). Sin APIs nuestras.
abstract class VoicePlaybackGateway {
  Future<void> speak(String text);

  Future<void> stop();
}
