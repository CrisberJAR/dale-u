class OrderException implements Exception {
  const OrderException(this.userMessage);

  final String userMessage;
}
