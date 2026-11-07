/// Fallos de autenticación seguros para UI: nunca incluyen tokens ni
/// el texto crudo de excepciones nativas.
enum AuthFailureType { cancelled, configuration, network, missingToken, unknown }

final class AuthFailure {
  const AuthFailure(this.type, {required this.userMessage});

  const AuthFailure.cancelled()
    : type = AuthFailureType.cancelled,
      userMessage = '';

  const AuthFailure.configuration()
    : type = AuthFailureType.configuration,
      userMessage =
          'La app no está configurada para Google Sign-In. Revisa .env y SHA-1.';

  const AuthFailure.network()
    : type = AuthFailureType.network,
      userMessage = 'Sin conexión. Revisa tu red e inténtalo de nuevo.';

  const AuthFailure.missingToken()
    : type = AuthFailureType.missingToken,
      userMessage = 'Google no devolvió un token válido. Revisa el Client ID web.';

  const AuthFailure.unknown()
    : type = AuthFailureType.unknown,
      userMessage = 'No se pudo iniciar sesión. Inténtalo de nuevo.';

  final AuthFailureType type;
  final String userMessage;

  bool get isCancelled => type == AuthFailureType.cancelled;
}
