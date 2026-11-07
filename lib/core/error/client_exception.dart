class ClientException implements Exception {
  const ClientException(this.userMessage);

  final String userMessage;
}
