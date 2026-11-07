import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

String syncErrorMessage(Object error) {
  if (error is TimeoutException) {
    return 'La nube tardó demasiado. Los clientes siguen en el teléfono.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firebase rechazó la subida. Publica firestore.rules: Consola → Firestore → Reglas → Publicar.';
      case 'unauthenticated':
        return 'La sesión expiró. Cierra sesión y vuelve a entrar.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'La nube no responde. Los clientes siguen en el teléfono.';
      default:
        return 'No se pudo subir a la nube (${error.code}). Los clientes siguen en el teléfono.';
    }
  }
  return 'No se pudo subir a la nube. Los clientes siguen en el teléfono.';
}
