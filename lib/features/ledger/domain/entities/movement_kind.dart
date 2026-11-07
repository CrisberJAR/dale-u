enum MovementKind {
  fiado,
  pago;

  String get spokenLabel => this == MovementKind.fiado ? 'Fiado' : 'Pago';

  static MovementKind? tryParse(String raw) {
    switch (raw) {
      case 'fiado':
        return MovementKind.fiado;
      case 'pago':
        return MovementKind.pago;
      default:
        return null;
    }
  }
}
