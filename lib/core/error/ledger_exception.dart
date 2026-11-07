class LedgerException implements Exception {
  const LedgerException(this.userMessage);

  final String userMessage;
}
