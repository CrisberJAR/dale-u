class BuyerException implements Exception {
  const BuyerException(this.userMessage);

  final String userMessage;
}
