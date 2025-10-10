import 'dart:collection';

import 'package:flutter/material.dart';

import 'admin_permissions.dart';

/// Describes the contextual data needed to evaluate menu visibility.
class AdminMenuAccessContext {
  final bool isSuperAdmin;
  final bool isCategoryAdmin;
  final Set<String> grantedPermissionKeys;
  final Map<String, List<String>> categoryScopes;

  const AdminMenuAccessContext({
    required this.grantedPermissionKeys,
    this.isSuperAdmin = false,
    this.isCategoryAdmin = false,
    this.categoryScopes = const {},
  });

  bool hasPermission(PermissionKey permission) {
    if (isSuperAdmin) return true;
    return grantedPermissionKeys.contains(permission.value);
  }

  bool hasScopedPermission(PermissionKey permission) {
    if (!isCategoryAdmin) return false;
    if (isSuperAdmin) return true;

    final scopeActions = categoryScopes.values;
    if (scopeActions.isEmpty) return false;

    return scopeActions.any((actions) => actions.contains(permission.action));
  }
}

/// Metadata representing a menu entry in the admin consoles.
class AdminMenuItemDefinition {
  final String id;
  final String title;
  final IconData icon;
  final String description;
  final List<PermissionKey> requireAll;
  final List<PermissionKey> requireAny;
  final bool superAdminOnly;
  final bool allowCategoryScope;
  final List<PermissionKey> highlightedActions;

  const AdminMenuItemDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    this.requireAll = const [],
    this.requireAny = const [],
    this.superAdminOnly = false,
    this.allowCategoryScope = false,
    this.highlightedActions = const [],
  });

  bool isVisible(AdminMenuAccessContext ctx) {
    if (superAdminOnly && !ctx.isSuperAdmin) {
      return false;
    }

    if (requireAll.isNotEmpty) {
      final allSatisfied = requireAll.every(
        (perm) =>
            ctx.hasPermission(perm) ||
            (allowCategoryScope && ctx.hasScopedPermission(perm)),
      );
      if (!allSatisfied) {
        return false;
      }
    }

    if (requireAny.isEmpty) {
      return true;
    }

    return requireAny.any(
      (perm) =>
          ctx.hasPermission(perm) ||
          (allowCategoryScope && ctx.hasScopedPermission(perm)),
    );
  }
}

/// Catalog of menu items for super admin and admin experiences.
class AdminMenuCatalog {
  static final List<AdminMenuItemDefinition> _superAdminMenu = [
    AdminMenuItemDefinition(
      id: 'dashboard',
      title: 'Dashboard',
      icon: Icons.dashboard,
      description: 'Finans ve operasyonların üst düzey özeti.',
    ),
    AdminMenuItemDefinition(
      id: 'users',
      title: 'Users',
      icon: Icons.people_alt,
      description: 'Kullanıcı yönetimi ve rol ataması.',
      requireAll: [AdminPermissions.usersView],
      highlightedActions: [
        AdminPermissions.usersDisable,
        AdminPermissions.usersSetRole,
        AdminPermissions.usersMaskPii,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'vendors',
      title: 'Vendors',
      icon: Icons.store_mall_directory,
      description: 'Satıcı onayları ve denetimi.',
      requireAll: [AdminPermissions.vendorsView],
      highlightedActions: [
        AdminPermissions.vendorsApprove,
        AdminPermissions.vendorsReject,
        AdminPermissions.vendorsSuspend,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'products',
      title: 'Products',
      icon: Icons.inventory_2,
      description: 'Katalog onayları ve moderasyon.',
      requireAny: [AdminPermissions.productsView],
      allowCategoryScope: true,
      highlightedActions: [
        AdminPermissions.productsApprove,
        AdminPermissions.productsArchive,
        AdminPermissions.productsFeature,
        AdminPermissions.productsModerateContent,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'orders',
      title: 'Orders / Escrow',
      icon: Icons.shopping_bag,
      description: 'Sipariş, escrow ve itiraz yönetimi.',
      requireAll: [AdminPermissions.ordersView],
      highlightedActions: [
        AdminPermissions.ordersRelease,
        AdminPermissions.ordersRefund,
        AdminPermissions.ordersDisputeResolve,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'disputes',
      title: 'Disputes',
      icon: Icons.gavel,
      description: 'İtiraz değerlendirme ve karar süreçleri.',
    ),
    AdminMenuItemDefinition(
      id: 'accounting',
      title: 'Accounting',
      icon: Icons.account_balance,
      description: 'Yevmiye defteri ve mutabakat.',
      superAdminOnly: true,
      requireAny: [AdminPermissions.accountingView],
      highlightedActions: [
        AdminPermissions.accountingPostManual,
        AdminPermissions.accountingAdjust,
        AdminPermissions.accountingReconciliationRun,
        AdminPermissions.accountingReconciliationApply,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'invoices',
      title: 'Invoices',
      icon: Icons.receipt_long,
      description: 'Fatura oluşturma ve iptal.',
      superAdminOnly: true,
      requireAny: [AdminPermissions.invoicesView],
      highlightedActions: [
        AdminPermissions.invoicesIssue,
        AdminPermissions.invoicesCancel,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'cashbox',
      title: 'Cashbox',
      icon: Icons.account_balance_wallet,
      description: 'Kasadan nakit giriş/çıkış ve iki imza akışı.',
      superAdminOnly: true,
      requireAny: [AdminPermissions.cashboxView],
      highlightedActions: [
        AdminPermissions.cashboxCashIn,
        AdminPermissions.cashboxCashOut,
        AdminPermissions.cashboxTwoManRuleBypass,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'payouts',
      title: 'Payouts',
      icon: Icons.payments,
      description: 'Ödeme planlama ve işleme.',
      superAdminOnly: true,
      requireAny: [AdminPermissions.payoutsView],
      highlightedActions: [
        AdminPermissions.payoutsSchedule,
        AdminPermissions.payoutsProcess,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'market_config',
      title: 'Market Config',
      icon: Icons.tune,
      description: 'Kategori ve komisyon yapılandırması.',
      requireAny: [AdminPermissions.marketCategoryCrud],
      highlightedActions: [
        AdminPermissions.marketCommissionSet,
        AdminPermissions.marketAllowlistSet,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'system_settings',
      title: 'System Settings',
      icon: Icons.settings_suggest,
      description: 'Bakım modu, App Check ve anahtar yönetimi.',
      superAdminOnly: true,
      requireAny: [AdminPermissions.systemMaintenanceToggle],
      highlightedActions: [
        AdminPermissions.systemAppCheckView,
        AdminPermissions.systemFunctionsHealth,
        AdminPermissions.systemKeysView,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'policies_roles',
      title: 'Policies & Roles',
      icon: Icons.admin_panel_settings,
      description: 'Rol tanımları, izin atama ve iki imza onayları.',
      superAdminOnly: true,
      requireAny: [AdminPermissions.policyRoleDefine],
      highlightedActions: [
        AdminPermissions.policyPermissionGrant,
        AdminPermissions.policyPermissionRevoke,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'audit_logs',
      title: 'Audit / Logs',
      icon: Icons.list_alt,
      description: 'İşlem ve denetim kayıtlarına erişim.',
      superAdminOnly: true,
      requireAny: [AdminPermissions.auditViewAll],
      highlightedActions: [
        AdminPermissions.auditExport,
        AdminPermissions.auditImpersonateView,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'reports',
      title: 'Reports',
      icon: Icons.bar_chart,
      description: 'Operasyonel raporlar ve veri dışa aktarma.',
      requireAny: [AdminPermissions.reportsView],
      highlightedActions: [AdminPermissions.reportsDownload],
    ),
  ];

  static final List<AdminMenuItemDefinition> _defaultAdminMenu = [
    AdminMenuItemDefinition(
      id: 'dashboard',
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      description: 'Operasyonel özet ve görev kuyrukları.',
    ),
    AdminMenuItemDefinition(
      id: 'users',
      title: 'Users',
      icon: Icons.people_outline,
      description: 'Kullanıcı yönetimi (PII maskeli).',
      requireAny: [AdminPermissions.usersView],
      highlightedActions: [AdminPermissions.usersDisable],
    ),
    AdminMenuItemDefinition(
      id: 'vendors',
      title: 'Vendors',
      icon: Icons.storefront,
      description: 'Satıcı başvuruları ve denetimi.',
      requireAny: [AdminPermissions.vendorsView],
      highlightedActions: [
        AdminPermissions.vendorsApprove,
        AdminPermissions.vendorsReject,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'products',
      title: 'Products',
      icon: Icons.inventory,
      description: 'Ürün onayları ve içerik moderasyonu.',
      requireAny: [AdminPermissions.productsView],
      allowCategoryScope: true,
      highlightedActions: [
        AdminPermissions.productsApprove,
        AdminPermissions.productsArchive,
        AdminPermissions.productsModerateContent,
      ],
    ),
    AdminMenuItemDefinition(
      id: 'orders',
      title: 'Orders / Disputes',
      icon: Icons.assignment,
      description: 'Sipariş görünümleri ve itiraz önerileri.',
      requireAny: [AdminPermissions.ordersView],
      highlightedActions: [AdminPermissions.ordersDisputeResolve],
    ),
    AdminMenuItemDefinition(
      id: 'reports',
      title: 'Reports',
      icon: Icons.pie_chart_outline,
      description: 'Operasyonel raporlar.',
      requireAny: [AdminPermissions.reportsView],
    ),
    AdminMenuItemDefinition(
      id: 'market_config',
      title: 'Market Config',
      icon: Icons.category_outlined,
      description: 'Kategori oluşturma ve düzenleme.',
      requireAny: [AdminPermissions.marketCategoryCrud],
    ),
  ];

  static UnmodifiableListView<AdminMenuItemDefinition> superAdminMenu() =>
      UnmodifiableListView(_superAdminMenu);

  static UnmodifiableListView<AdminMenuItemDefinition> defaultAdminMenu() =>
      UnmodifiableListView(_defaultAdminMenu);

  static List<AdminMenuItemDefinition> resolveMenu(AdminMenuAccessContext ctx) {
    if (ctx.isSuperAdmin) {
      return _superAdminMenu
          .where((item) => item.isVisible(ctx))
          .toList(growable: false);
    }

    final items = <AdminMenuItemDefinition>[];
    for (final item in _defaultAdminMenu) {
      if (item.isVisible(ctx)) {
        items.add(item);
      }
    }

    // Category admins may still need the policies page for scopes preview.
    if (ctx.isCategoryAdmin) {
      AdminMenuItemDefinition? scopedItem;
      for (final item in _superAdminMenu) {
        if (item.id == 'products') {
          scopedItem = item;
          break;
        }
      }
      if (scopedItem != null) {
        final menu = scopedItem;
        if (!items.any((i) => i.id == menu.id) && menu.isVisible(ctx)) {
          items.add(menu);
        }
      }
    }

    return items;
  }
}
