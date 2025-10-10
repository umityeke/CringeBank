import 'dart:collection';

/// Defines a strongly-typed key for an RBAC permission.
///
/// Permissions are expressed as `resource.action` pairs (e.g. `products.approve`).
/// They map 1:1 onto the SQL `permissions` table and Firebase custom claims.
class PermissionKey {
  final String resource;
  final String action;

  const PermissionKey(this.resource, this.action);

  String get value => '$resource.$action';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionKey &&
        other.resource == resource &&
        other.action == action;
  }

  @override
  int get hashCode => Object.hash(resource, action);

  @override
  String toString() => value;
}

/// Catalog of RBAC permissions referenced by the admin UI and backend guards.
///
/// Every permission in the taxonomy is represented as a constant for
/// compile-time safety and better refactorability.
abstract class AdminPermissions {
  // Users
  static const usersView = PermissionKey('users', 'view');
  static const usersDisable = PermissionKey('users', 'disable');
  static const usersSetRole = PermissionKey('users', 'set_role');
  static const usersMaskPii = PermissionKey('users', 'mask_pii');

  // Vendors
  static const vendorsView = PermissionKey('vendors', 'view');
  static const vendorsApprove = PermissionKey('vendors', 'approve');
  static const vendorsReject = PermissionKey('vendors', 'reject');
  static const vendorsSuspend = PermissionKey('vendors', 'suspend');

  // Products
  static const productsView = PermissionKey('products', 'view');
  static const productsApprove = PermissionKey('products', 'approve');
  static const productsArchive = PermissionKey('products', 'archive');
  static const productsFeature = PermissionKey('products', 'feature');
  static const productsModerateContent = PermissionKey(
    'products',
    'moderate_content',
  );

  // Orders / Escrow / Disputes
  static const ordersView = PermissionKey('orders', 'view');
  static const ordersRelease = PermissionKey('orders', 'release');
  static const ordersRefund = PermissionKey('orders', 'refund');
  static const ordersDisputeResolve = PermissionKey(
    'orders',
    'dispute_resolve',
  );

  // Wallet / Ledger
  static const ledgerViewSummary = PermissionKey(
    'wallet_ledger',
    'view_summary',
  );
  static const ledgerViewDetailMasked = PermissionKey(
    'wallet_ledger',
    'view_detail_masked',
  );
  static const ledgerViewDetailFull = PermissionKey(
    'wallet_ledger',
    'view_detail_full',
  );
  static const ledgerExport = PermissionKey('wallet_ledger', 'export');

  // Accounting (Journal)
  static const accountingView = PermissionKey('accounting', 'view');
  static const accountingPostManual = PermissionKey(
    'accounting',
    'post_manual',
  );
  static const accountingAdjust = PermissionKey('accounting', 'adjust');
  static const accountingReconciliationRun = PermissionKey(
    'accounting',
    'reconciliation_run',
  );
  static const accountingReconciliationApply = PermissionKey(
    'accounting',
    'reconciliation_apply',
  );

  // Invoices
  static const invoicesView = PermissionKey('invoices', 'view');
  static const invoicesIssue = PermissionKey('invoices', 'issue');
  static const invoicesCancel = PermissionKey('invoices', 'cancel');

  // Cashbox
  static const cashboxView = PermissionKey('cashbox', 'view');
  static const cashboxCashIn = PermissionKey('cashbox', 'cash_in');
  static const cashboxCashOut = PermissionKey('cashbox', 'cash_out');
  static const cashboxTwoManRuleBypass = PermissionKey(
    'cashbox',
    'two_man_rule_bypass',
  );

  // Payouts
  static const payoutsView = PermissionKey('payouts', 'view');
  static const payoutsSchedule = PermissionKey('payouts', 'schedule');
  static const payoutsProcess = PermissionKey('payouts', 'process');

  // Market Config
  static const marketCategoryCrud = PermissionKey(
    'market_config',
    'category_crud',
  );
  static const marketCommissionSet = PermissionKey(
    'market_config',
    'commission_set',
  );
  static const marketAllowlistSet = PermissionKey(
    'market_config',
    'allowlist_set',
  );

  // System Settings
  static const systemMaintenanceToggle = PermissionKey(
    'system_settings',
    'maintenance_toggle',
  );
  static const systemAppCheckView = PermissionKey(
    'system_settings',
    'appcheck_view',
  );
  static const systemFunctionsHealth = PermissionKey(
    'system_settings',
    'functions_health',
  );
  static const systemKeysView = PermissionKey('system_settings', 'keys_view');

  // Policy / Role Management
  static const policyRoleDefine = PermissionKey('policies', 'role_define');
  static const policyPermissionGrant = PermissionKey(
    'policies',
    'permission_grant',
  );
  static const policyPermissionRevoke = PermissionKey(
    'policies',
    'permission_revoke',
  );

  // Audit / Logs
  static const auditViewAll = PermissionKey('audit', 'view_all');
  static const auditExport = PermissionKey('audit', 'export');
  static const auditImpersonateView = PermissionKey(
    'audit',
    'impersonate_view',
  );

  // Reports (Operational)
  static const reportsView = PermissionKey('reports', 'view');
  static const reportsDownload = PermissionKey('reports', 'download');

  // Simulation / Tooling (bonus suggestions)
  static const simulationPreview = PermissionKey('simulation', 'preview_as');
  static const policiesSchedule = PermissionKey('policies', 'schedule_policy');

  /// High-risk actions that must pass the "two-man" approval flow.
  static final Set<PermissionKey> criticalDualControlActions =
      UnmodifiableSetView(<PermissionKey>{
        cashboxCashOut,
        accountingAdjust,
        accountingReconciliationApply,
        payoutsProcess,
        invoicesCancel,
      });

  /// Default permission presets for quick role assignment.
  static final Map<String, Set<PermissionKey>>
  rolePresets = UnmodifiableMapView(<String, Set<PermissionKey>>{
    'superadmin': {
      // Super admin implicitly receives every permission. We still list core
      // permissions so the UI can highlight coverage.
      usersView,
      usersDisable,
      usersSetRole,
      vendorsView,
      vendorsApprove,
      vendorsReject,
      vendorsSuspend,
      productsView,
      productsApprove,
      productsArchive,
      productsFeature,
      productsModerateContent,
      ordersView,
      ordersRelease,
      ordersRefund,
      ordersDisputeResolve,
      ledgerViewSummary,
      ledgerViewDetailMasked,
      ledgerViewDetailFull,
      ledgerExport,
      accountingView,
      accountingPostManual,
      accountingAdjust,
      accountingReconciliationRun,
      accountingReconciliationApply,
      invoicesView,
      invoicesIssue,
      invoicesCancel,
      cashboxView,
      cashboxCashIn,
      cashboxCashOut,
      payoutsView,
      payoutsSchedule,
      payoutsProcess,
      marketCategoryCrud,
      marketCommissionSet,
      marketAllowlistSet,
      systemMaintenanceToggle,
      systemAppCheckView,
      systemFunctionsHealth,
      systemKeysView,
      policyRoleDefine,
      policyPermissionGrant,
      policyPermissionRevoke,
      auditViewAll,
      auditExport,
      auditImpersonateView,
      reportsView,
      reportsDownload,
      simulationPreview,
      policiesSchedule,
    },
    'admin_default': {
      usersView,
      usersDisable,
      usersMaskPii,
      vendorsView,
      vendorsApprove,
      vendorsReject,
      productsView,
      productsApprove,
      productsArchive,
      productsFeature,
      productsModerateContent,
      ordersView,
      ordersDisputeResolve,
      ledgerViewSummary,
      ledgerViewDetailMasked,
      marketCategoryCrud,
      reportsView,
    },
    'category_admin': {
      productsView,
      productsApprove,
      productsArchive,
      productsModerateContent,
    },
  });
}

extension PermissionKeyListX on Iterable<PermissionKey> {
  List<String> toValues() => map((p) => p.value).toList(growable: false);
}
