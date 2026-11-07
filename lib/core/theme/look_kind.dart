/// Dos pieles. La lógica de la app no cambia.
enum LookKind {
  bakery,
  classic;

  static LookKind parse(String? raw) {
    if (raw == 'classic') return LookKind.classic;
    return LookKind.bakery;
  }
}
