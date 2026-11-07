import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole.parse', () {
    test('acepta cliente, vendedor y admin', () {
      expect(UserRole.parse('vendedor'), UserRole.vendedor);
      expect(UserRole.parse(' Cliente '), UserRole.cliente);
      expect(UserRole.parse('ADMIN'), UserRole.admin);
    });

    test('rechaza cualquier otro texto', () {
      expect(UserRole.parse('superadmin'), isNull);
      expect(UserRole.parse('DROP TABLE'), isNull);
      expect(UserRole.parse(''), isNull);
      expect(UserRole.parse(null), isNull);
    });
  });

  group('permisos', () {
    test('solo vendedor y admin trabajan la ruta', () {
      expect(UserRole.cliente.canSell, isFalse);
      expect(UserRole.vendedor.canSell, isTrue);
      expect(UserRole.admin.canSell, isTrue);
    });

    test('solo el admin nombra cuentas', () {
      expect(UserRole.cliente.canManageAccounts, isFalse);
      expect(UserRole.vendedor.canManageAccounts, isFalse);
      expect(UserRole.admin.canManageAccounts, isTrue);
    });
  });
}
