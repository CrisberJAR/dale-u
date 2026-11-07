class RoleException implements Exception {
  const RoleException(this.userMessage);

  final String userMessage;
}
