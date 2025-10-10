import 'dart:collection';

import 'admin_menu_definition.dart';
import 'admin_permissions.dart';
import 'user_model.dart';

extension UserPermissionExtension on User {
  /// Returns the active admin roles for which the assignment is active and not expired.
  Iterable<AdminRoleAssignment> get activeAdminRoles =>
      adminRoles.where((role) => role.isActive);

  bool get isAdminRole =>
      isSuperAdmin || activeAdminRoles.any((role) => role.role == 'admin');

  bool get isCategoryAdminRole =>
      activeAdminRoles.any((role) => role.role.startsWith('category_admin')) ||
      categoryPermissions.isNotEmpty;

  /// Aggregated permission keys including explicit grants and role presets.
  Set<String> get activePermissionKeys {
    final normalized = <String>{};
    for (final permission in grantedPermissions) {
      final key = permission.trim().toLowerCase();
      if (key.isNotEmpty) {
        normalized.add(key);
      }
    }

    for (final role in activeAdminRoles) {
      final preset = AdminPermissions.rolePresets[role.role];
      if (preset != null) {
        for (final perm in preset) {
          normalized.add(perm.value);
        }
      }
    }

    if (isSuperAdmin) {
      final preset = AdminPermissions.rolePresets['superadmin'];
      if (preset != null) {
        for (final perm in preset) {
          normalized.add(perm.value);
        }
      }
    }

    return UnmodifiableSetView(normalized);
  }

  bool canPerform(PermissionKey permission, {String? category}) {
    if (isSuperAdmin) {
      return true;
    }

    if (activePermissionKeys.contains(permission.value)) {
      return true;
    }

    if (category != null) {
      final scopedActions = categoryPermissions[category];
      if (scopedActions != null && scopedActions.contains(permission.action)) {
        return true;
      }
    }

    return false;
  }

  bool canPerformAny(Iterable<PermissionKey> permissions, {String? category}) {
    for (final permission in permissions) {
      if (canPerform(permission, category: category)) {
        return true;
      }
    }
    return false;
  }

  AdminMenuAccessContext toMenuContext() {
    return AdminMenuAccessContext(
      grantedPermissionKeys: activePermissionKeys,
      isSuperAdmin: isSuperAdmin,
      isCategoryAdmin: isCategoryAdminRole,
      categoryScopes: categoryPermissions,
    );
  }
}
