class PresenceException implements Exception {
  const PresenceException(this.userMessage);

  final String userMessage;
}
