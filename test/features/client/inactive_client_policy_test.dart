import 'package:dale_u/features/client/domain/inactive_client_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 31);

  test('activo no se borra', () {
    expect(
      InactiveClientPolicy.shouldPurge(
        active: true,
        updatedAt: DateTime.utc(2026, 1, 1),
        lastMovementAt: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('desactivado hace 30 días sin movimientos se borra', () {
    expect(
      InactiveClientPolicy.shouldPurge(
        active: false,
        updatedAt: DateTime.utc(2026, 8, 1),
        lastMovementAt: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('desactivado hace 29 días aún no', () {
    expect(
      InactiveClientPolicy.shouldPurge(
        active: false,
        updatedAt: DateTime.utc(2026, 8, 2),
        lastMovementAt: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('un movimiento reciente detiene la purga', () {
    expect(
      InactiveClientPolicy.shouldPurge(
        active: false,
        updatedAt: DateTime.utc(2026, 6, 1),
        lastMovementAt: DateTime.utc(2026, 8, 20),
        now: now,
      ),
      isFalse,
    );
  });
}
