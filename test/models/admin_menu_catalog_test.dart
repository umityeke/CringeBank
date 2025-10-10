import 'package:flutter_test/flutter_test.dart';
import 'package:cringe_bankasi/models/admin_menu_definition.dart';
import 'package:cringe_bankasi/models/admin_permissions.dart';

void main() {
  group('AdminMenuCatalog.resolveMenu', () {
    test('returns full menu for super admin', () {
      final ctx = AdminMenuAccessContext(
        grantedPermissionKeys: <String>{},
        isSuperAdmin: true,
      );

      final menu = AdminMenuCatalog.resolveMenu(ctx);
      final superMenu = AdminMenuCatalog.superAdminMenu();

      expect(
        menu.map((item) => item.id).toList(),
        equals(superMenu.map((item) => item.id).toList()),
      );
    });

    test('filters default admin menu by permissions', () {
      final ctx = AdminMenuAccessContext(
        grantedPermissionKeys: {
          AdminPermissions.usersView.value,
          AdminPermissions.productsView.value,
        },
      );

      final menu = AdminMenuCatalog.resolveMenu(ctx);
      final ids = menu.map((item) => item.id).toList();

      expect(ids, contains('dashboard'));
      expect(ids, contains('users'));
      expect(ids, contains('products'));
      expect(ids, isNot(contains('vendors')));
      expect(ids, isNot(contains('reports')));
    });

    test('category admin gains scoped products access', () {
      final ctx = AdminMenuAccessContext(
        grantedPermissionKeys: <String>{},
        isCategoryAdmin: true,
        categoryScopes: const {
          'elektronik': ['view', 'approve'],
        },
      );

      final menu = AdminMenuCatalog.resolveMenu(ctx);
      expect(menu.map((item) => item.id), contains('products'));
    });
  });
}
