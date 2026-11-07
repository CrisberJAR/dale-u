class NoticeException implements Exception {
  const NoticeException(this.userMessage);

  final String userMessage;
}
