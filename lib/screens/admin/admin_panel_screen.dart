import 'package:flutter/material.dart';

import '../../models/admin_menu_definition.dart';
import '../../models/admin_permissions.dart';
import '../../models/special_project_config.dart';
import '../../models/user_model.dart';
import '../../models/user_permission_extensions.dart';
import '../../services/special_projects_config_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

typedef AdminPageBuilder =
    Widget Function(
      BuildContext context,
      User user,
      AdminMenuItemDefinition menu,
      AdminMenuAccessContext ctx,
    );

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: UserService.instance.userDataStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AdminLoadingScaffold();
        }

        final user = snapshot.data ?? UserService.instance.currentUser;
        if (user == null) {
          return const _AdminNoAccessScaffold(
            title: 'Giriş gerekli',
            message: 'Admin paneline erişmek için önce giriş yapmanız gerekir.',
          );
        }

        final ctx = user.toMenuContext();
        if (!ctx.isSuperAdmin &&
            !user.isAdminRole &&
            !user.isCategoryAdminRole) {
          return const _AdminNoAccessScaffold(
            title: 'Yetkiniz yok',
            message:
                'Bu panel sadece atanmış admin veya süper admin kullanıcılar içindir.',
          );
        }

        final menuItems = AdminMenuCatalog.resolveMenu(ctx);
        if (menuItems.isEmpty) {
          return const _AdminNoAccessScaffold(
            title: 'Menü bulunamadı',
            message:
                'Hesabınız için tanımlı herhangi bir admin menüsü bulunamadı. Lütfen süper admin ile iletişime geçin.',
          );
        }

        return _AdminPanelView(user: user, menuItems: menuItems, ctx: ctx);
      },
    );
  }
}

class _AdminLoadingScaffold extends StatelessWidget {
  const _AdminLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AdminNoAccessScaffold extends StatelessWidget {
  final String title;
  final String message;

  const _AdminNoAccessScaffold({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade500),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminPanelView extends StatefulWidget {
  final User user;
  final List<AdminMenuItemDefinition> menuItems;
  final AdminMenuAccessContext ctx;

  const _AdminPanelView({
    required this.user,
    required this.menuItems,
    required this.ctx,
  });

  @override
  State<_AdminPanelView> createState() => _AdminPanelViewState();
}

class _AdminPanelViewState extends State<_AdminPanelView> {
  late String _selectedMenuId;

  List<AdminMenuItemDefinition> get menuItems => widget.menuItems;

  @override
  void initState() {
    super.initState();
    _selectedMenuId = menuItems.first.id;
  }

  @override
  void didUpdateWidget(covariant _AdminPanelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!menuItems.any((item) => item.id == _selectedMenuId)) {
      setState(() {
        _selectedMenuId = menuItems.first.id;
      });
    }
  }

  void _onSelect(String menuId) {
    if (_selectedMenuId == menuId) return;
    setState(() {
      _selectedMenuId = menuId;
    });
  }

  void _handleExit(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMenu = menuItems.firstWhere(
      (item) => item.id == _selectedMenuId,
      orElse: () => menuItems.first,
    );

    final isWide = MediaQuery.of(context).size.width >= 1180;
    final content = _buildContent(selectedMenu);

    if (isWide) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Row(
          children: [
            _buildNavigationRail(selectedMenu.id),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: content,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(showDrawerButton: true),
      drawer: _AdminMenuDrawer(
        menuItems: menuItems,
        selectedMenuId: selectedMenu.id,
        onSelect: (id) {
          Navigator.of(context).pop();
          _onSelect(id);
        },
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: content,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({bool showDrawerButton = false}) {
    return AppBar(
      title: Text(
        widget.ctx.isSuperAdmin ? 'Süper Admin Paneli' : 'Admin Paneli',
      ),
      backgroundColor: AppTheme.primaryColor,
      leading: showDrawerButton ? null : const BackButton(),
      actions: [
        IconButton(
          tooltip: 'Ana uygulamaya dön',
          icon: const Icon(Icons.exit_to_app),
          onPressed: () => _handleExit(context),
        ),
        if (widget.ctx.isSuperAdmin)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Chip(
              label: Text('Superadmin'),
              avatar: Icon(Icons.verified_user, color: Colors.white),
              backgroundColor: Colors.deepPurple,
              labelStyle: TextStyle(color: Colors.white),
            ),
          )
        else if (widget.ctx.isCategoryAdmin)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Chip(
              label: Text('Category Admin'),
              avatar: Icon(Icons.category, color: Colors.white),
              backgroundColor: Colors.orange,
              labelStyle: TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildNavigationRail(String selectedId) {
    return NavigationRail(
      selectedIndex: menuItems.indexWhere((item) => item.id == selectedId),
      labelType: NavigationRailLabelType.all,
      backgroundColor: Colors.grey.shade100,
      onDestinationSelected: (index) {
        final item = menuItems[index];
        _onSelect(item.id);
      },
      destinations: [
        for (final item in menuItems)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.icon, color: AppTheme.primaryColor),
            label: Text(item.title),
          ),
      ],
    );
  }

  Widget _buildContent(AdminMenuItemDefinition menu) {
    final builder = _pageBuilders[menu.id] ?? _placeholderBuilder;
    return builder(context, widget.user, menu, widget.ctx);
  }
}

class _AdminMenuDrawer extends StatelessWidget {
  final List<AdminMenuItemDefinition> menuItems;
  final String selectedMenuId;
  final ValueChanged<String> onSelect;

  const _AdminMenuDrawer({
    required this.menuItems,
    required this.selectedMenuId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Admin Paneli',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'İzinlerinize göre menü otomatik şekillenir.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            for (final item in menuItems)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                selected: item.id == selectedMenuId,
                onTap: () => onSelect(item.id),
              ),
          ],
        ),
      ),
    );
  }
}

class AdminInfoSection {
  final String title;
  final List<String> bullets;
  final IconData icon;
  final Color? color;

  const AdminInfoSection({
    required this.title,
    required this.bullets,
    required this.icon,
    this.color,
  });
}

class AdminInfoPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<AdminInfoSection> sections;
  final List<Widget> trailing;
  final AdminMenuItemDefinition menu;
  final AdminMenuAccessContext? ctx;

  const AdminInfoPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.menu,
    this.trailing = const [],
    this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in menu.highlightedActions)
                    if (_canHighlight(action))
                      Chip(
                        backgroundColor: Colors.blueGrey.shade50,
                        avatar: const Icon(Icons.verified, size: 18),
                        label: Text(action.value),
                      ),
                ],
              ),
              const SizedBox(height: 24),
              for (final section in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    elevation: 0,
                    color: section.color ?? Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (section.color ?? Colors.white)
                                    .withOpacity(0.1),
                                child: Icon(
                                  section.icon,
                                  color: section.color != null
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  section.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final bullet in section.bullets)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 8,
                                left: 4,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(
                                    child: Text(
                                      bullet,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ...trailing,
            ],
          ),
        ),
      ),
    );
  }

  bool _canHighlight(PermissionKey action) {
    final contextData = ctx;
    if (contextData == null) {
      return true;
    }
    return contextData.hasPermission(action) ||
        contextData.hasScopedPermission(action);
  }
}

final Map<String, AdminPageBuilder> _pageBuilders = {
  'dashboard': _dashboardBuilder,
  'users': _usersBuilder,
  'vendors': _vendorsBuilder,
  'products': _productsBuilder,
  'orders': _ordersBuilder,
  'disputes': _disputesBuilder,
  'accounting': _accountingBuilder,
  'invoices': _invoicesBuilder,
  'cashbox': _cashboxBuilder,
  'payouts': _payoutsBuilder,
  'market_config': _marketConfigBuilder,
  'system_settings': _systemSettingsBuilder,
  'policies_roles': _policiesBuilder,
  'audit_logs': _auditBuilder,
  'reports': _reportsBuilder,
};

Widget _placeholderBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: menu.title,
    subtitle:
        'Bu menü için ayrıntılı ekranlar henüz uygulanmadı. Şu an yer tutucu görünüm gösteriliyor.',
    sections: const [
      AdminInfoSection(
        title: 'Yapılacaklar',
        bullets: [
          'Ürün geliştirme planında bu ekran için detaylar tanımlanmalı.',
        ],
        icon: Icons.pending_actions,
      ),
    ],
    menu: menu,
    ctx: ctx,
  );
}

Widget _dashboardBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  final pendingApprovals = user.pendingApprovals
      .where((approval) => !approval.isResolved)
      .toList();
  final activeSuperAdmins = user.adminRoles
      .where((role) => role.role == 'superadmin' && role.isActive)
      .length;
  final categoryScopes = user.categoryPermissions;

  final service = SpecialProjectsConfigService.instance;

  return StreamBuilder<List<SpecialProjectConfig>>(
    stream: service.watchActiveProjects(),
    builder: (context, snapshot) {
      final projects = snapshot.data ?? const <SpecialProjectConfig>[];

      final trailingWidgets = <Widget>[
        const SizedBox(height: 24),
        const _SimulationModeCard(),
      ];

      if (snapshot.hasError) {
        trailingWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              elevation: 0,
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Özel projeler yüklenirken hata oluştu. Lütfen daha sonra tekrar deneyin.',
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else if (snapshot.connectionState == ConnectionState.waiting &&
          projects.isEmpty) {
        trailingWidgets.add(
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: _DashboardLoadingCard(),
          ),
        );
      } else if (projects.isNotEmpty) {
        for (final project in projects) {
          trailingWidgets.add(_SpecialProjectCard(project: project));
        }
      }

      return AdminInfoPage(
        title: ctx.isSuperAdmin ? 'Kontrol Merkezi' : 'Admin Kontrol Merkezi',
        subtitle:
            'Sistem sağlığı, bekleyen onaylar ve kritik finans görevleri burada özetlenir.',
        menu: menu,
        ctx: ctx,
        sections: [
          AdminInfoSection(
            title: 'Bekleyen Süper Admin Onayları',
            bullets: pendingApprovals.isEmpty
                ? const ['Bekleyen onay bulunmuyor.']
                : pendingApprovals
                      .map(
                        (approval) =>
                            '${approval.type} · ${approval.requiredApprovals} onay gerekiyor · ${approval.createdAt.toLocal()}',
                      )
                      .toList(),
            icon: Icons.how_to_vote,
          ),
          AdminInfoSection(
            title: 'İki İmza Gerektiren İşlemler',
            bullets: AdminPermissions.criticalDualControlActions
                .map(
                  (perm) =>
                      '${perm.resource}.${perm.action} · minimum 2 süper admin onayı',
                )
                .toList(),
            icon: Icons.handshake,
          ),
          AdminInfoSection(
            title: 'Aktif Rollerin Özeti',
            bullets: [
              'Aktif Süper Admin sayısı: $activeSuperAdmins',
              if (categoryScopes.isNotEmpty)
                'Kategori yetki kapsamı: ${categoryScopes.keys.join(', ')}',
              'Claims versiyonu: ${user.claimsVersion}',
            ],
            icon: Icons.manage_accounts,
          ),
        ],
        trailing: trailingWidgets,
      );
    },
  );
}

class _SimulationModeCard extends StatelessWidget {
  const _SimulationModeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Simülasyon Modu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Süper adminler, bir UID seçip ilgili adminin panelini readonly görüntüleyebilir. '
              'Bu özellik, yanlış yetki setlerini hızlıca analiz etmek için kullanılacak.',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoadingCard extends StatelessWidget {
  const _DashboardLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Özel projeler yükleniyor...')),
          ],
        ),
      ),
    );
  }
}

class _SpecialProjectCard extends StatelessWidget {
  final SpecialProjectConfig project;

  const _SpecialProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    project.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (project.priority != 0)
                  Chip(
                    label: Text('Öncelik ${project.priority}'),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                    labelStyle: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(project.description, style: theme.textTheme.bodyMedium),
            if (project.imageUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    project.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey.shade500,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _usersBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Kullanıcı Yönetimi',
    subtitle:
        'Süper adminler tüm kullanıcıları görebilir; normal adminler yalnız PII maskeli veri görür.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'Görüntüleme',
        bullets: [
          'Aktif/pasif kullanıcı listesi filtrelenebilir.',
          'PII alanları (email, telefon) maskeli gösterilir; maskeyi açmak sadece süper admin yetkisindedir.',
        ],
        icon: Icons.visibility,
      ),
      AdminInfoSection(
        title: 'Yetki Atama',
        bullets: [
          'Kullanıcıya admin rolü atarken izin şablonu seçilebilir (operasyon, katalog, destek).',
          'Her atama claims_version artırır ve token yenilemesi zorunlu hale gelir.',
        ],
        icon: Icons.rule_folder,
      ),
      AdminInfoSection(
        title: 'Denetim',
        bullets: [
          'Her rol değişimi audit loglarına yazılır.',
          'Revoke işlemlerinde kullanıcı paneli anında erişim kaybeder.',
        ],
        icon: Icons.fact_check,
      ),
    ],
  );
}

Widget _vendorsBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Satıcı Yönetimi',
    subtitle:
        'Başvuruların incelenmesi, askıya alma ve yeniden aktivasyon süreçleri.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'Başvuru Kuyruğu',
        bullets: [
          'Satıcı başvuruları risk skoruna göre sıralanır.',
          'Onay veya ret işlemleri Firestore yerine Cloud Functions üzerinden gerçekleşir.',
        ],
        icon: Icons.queue,
      ),
      AdminInfoSection(
        title: 'Risk Kontrolü',
        bullets: [
          'Süper adminler askıya alma ve yeniden aktivasyon gerçekleştirebilir.',
          'Her karar audit loguna ip ve cihaz bilgisiyle kaydedilir.',
        ],
        icon: Icons.security,
      ),
    ],
  );
}

Widget _productsBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  final categoryScopes = user.categoryPermissions;

  return AdminInfoPage(
    title: 'Ürün Moderasyonu',
    subtitle: ctx.isSuperAdmin
        ? 'Global katalog kontrolü ve kategori bazlı admin yönetimi.'
        : 'Atanmış izin kapsamına göre kategori bazlı moderasyon.',
    menu: menu,
    ctx: ctx,
    sections: [
      AdminInfoSection(
        title: 'Moderasyon Akışı',
        bullets: [
          'Yeni ürün onayları, içerik moderasyonu ve arşivleme tek ekrandan yönetilir.',
          if (categoryScopes.isNotEmpty)
            'Kategori kapsamınız: ${categoryScopes.entries.map((e) => '${e.key} (${e.value.join(', ')})').join('; ')}',
          'Harici API çağrıları RBAC policy evaluator tarafından korunur.',
        ],
        icon: Icons.inventory_2,
      ),
      const AdminInfoSection(
        title: 'Kilit Noktalar',
        bullets: [
          'Her moderasyon kararı, kategori bazlı scope kontrolünden geçer.',
          'Süper admin dilerse kategori adminini geçici süreliğine yetkilendirebilir.',
        ],
        icon: Icons.rule,
      ),
    ],
  );
}

Widget _ordersBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Sipariş & Escrow',
    subtitle:
        'Sipariş yaşam döngüsü, escrow serbest bırakma ve iade işlemleri tek panelde.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'İş Kuralları',
        bullets: [
          'Release işlemi sadece ESCROW_HELD durumunda yapılır.',
          'Refund işlemi, ledger dengelemesiyle eşleştirilir.',
          'Normal adminler sadece görüntüleme ve öneri bırakma yetkisine sahiptir.',
        ],
        icon: Icons.assignment_turned_in,
      ),
      AdminInfoSection(
        title: 'İtiraz Yönetimi',
        bullets: [
          'İtirazlar risk skoruna göre önceliklendirilir.',
          'Final karar yalnızca süper admin veya yetkili dispute ekibi tarafından verilir.',
        ],
        icon: Icons.gavel,
      ),
    ],
  );
}

Widget _disputesBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'İtiraz Merkezi',
    subtitle:
        'Dispute ekibi için özel kuyruk, delil yönetimi ve karar önerileri.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'Görev Akışı',
        bullets: [
          'Kanıtlar tek ekranda toplanır, kritik belgeler için Sentry watermark uygulanır.',
          'Normal adminler öneri bırakır, süper adminler finalize eder.',
        ],
        icon: Icons.policy,
      ),
      AdminInfoSection(
        title: 'Audit Şeffaflığı',
        bullets: [
          'Her karar, hangi delillere dayanıldığını not düşmek zorundadır.',
          'Kararlar audit loglarında tam izlenebilir şekilde tutulur.',
        ],
        icon: Icons.visibility,
      ),
    ],
  );
}

Widget _accountingBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Muhasebe & Defter',
    subtitle:
        'Yevmiye kayıtları, mutabakat ve iki imza gerektiren düzeltmeler.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'Journal İşlemleri',
        bullets: [
          'Manuel yevmiye kayıtları sadece süper admin tarafından oluşturulur.',
          'Düzeltme (adjust) eylemleri çift onaylı görevler kuyruğuna düşer.',
        ],
        icon: Icons.menu_book,
      ),
      AdminInfoSection(
        title: 'Mutabakat',
        bullets: [
          'reconciliation_run rapor üretir, reconciliation_apply uygulama için ikinci onay ister.',
          'Ledger detayları tam görünümde sağlanır; admin modunda yalnız özet erişimi bulunur.',
        ],
        icon: Icons.compare_arrows,
      ),
    ],
  );
}

Widget _invoicesBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Fatura Yönetimi',
    subtitle: 'Fatura oluşturma, düzenleme ve iptal süreçleri.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'Fatura Akışı',
        bullets: [
          'Fatura issue işlemleri tekil veya toplu yapılabilir.',
          'Cancel işlemi iki imza kuralına tabidir ve audit kaydı zorunludur.',
        ],
        icon: Icons.receipt_long,
      ),
      AdminInfoSection(
        title: 'Entegrasyon',
        bullets: [
          'E-belge entegrasyonları için webhook doğrulaması zorunludur.',
          'Faturalar ledger ile çapraz kontrol edilerek durumlanır.',
        ],
        icon: Icons.sync,
      ),
    ],
  );
}

Widget _cashboxBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Cashbox Operasyonları',
    subtitle:
        'Nakit giriş-çıkış süreci, iki imza gereklilikleri ve acil durum bypass akışı.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'İşleyiş',
        bullets: [
          'Cash-in işlemleri tek onayla, cash-out işlemleri iki süper admin onayıyla tamamlanır.',
          'Bypass yalnızca acil durumlarda kullanılabilir ve otomatik olarak incident açar.',
        ],
        icon: Icons.account_balance_wallet,
      ),
      AdminInfoSection(
        title: 'Kontroller',
        bullets: [
          'Kasadaki her hareket ledger ile eşleştirilir ve audit loguna düşer.',
          'Yetki dışı denemeler otomatik olarak alarm üretir.',
        ],
        icon: Icons.verified_user,
      ),
    ],
  );
}

Widget _payoutsBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Payout Yönetimi',
    subtitle: 'Planlama, onay ve işlem sıraları.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'Planlama',
        bullets: [
          'Payout schedule işlemleri risk ve hacme göre önceliklendirilir.',
          'İşleme alma (process) eylemi ikinci bir süper admin onayı gerektirir.',
        ],
        icon: Icons.event,
      ),
      AdminInfoSection(
        title: 'Takip',
        bullets: [
          'Her ödeme, bankacılık API durumlarıyla eşlenir.',
          'Geciken işlemler için otomatik uyarı sistemi bulunur.',
        ],
        icon: Icons.monitor_heart,
      ),
    ],
  );
}

Widget _marketConfigBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Pazar Yapılandırması',
    subtitle: 'Kategori yönetimi, komisyon oranları ve allowlist kontrolleri.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'Kategori İşlemleri',
        bullets: [
          'Kategori ekleme/silme ve slug yönetimi.',
          'Kategori adminleri için scope belirleme.',
        ],
        icon: Icons.category,
      ),
      AdminInfoSection(
        title: 'Finansal Parametreler',
        bullets: [
          'Komisyon oranları süper admin onayı gerektirir.',
          'Allowlist güncellemeleri audit loguna kaydedilir.',
        ],
        icon: Icons.percent,
      ),
    ],
  );
}

Widget _systemSettingsBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Sistem Ayarları',
    subtitle:
        'Bakım modu, App Check izleme, Functions sağlık raporları ve anahtar yönetimi.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'Bakım Modu',
        bullets: [
          'Bakım moduna geçerken kullanıcılar kademeli olarak bilgilendirilir.',
          'Bakım çıkışı sonrası token yenileme zorunlu kılınır.',
        ],
        icon: Icons.settings_backup_restore,
      ),
      AdminInfoSection(
        title: 'Servis Sağlığı',
        bullets: [
          'Cloud Functions health check sonuçları burada listelenir.',
          'App Check metrikleri izlenir, eşik aşımında alert üretir.',
        ],
        icon: Icons.health_and_safety,
      ),
      AdminInfoSection(
        title: 'Anahtar Yönetimi',
        bullets: [
          'Kritik anahtarlar (API, webhook) rotation takvimine göre yenilenir.',
          'Her erişim denemesi audit loguna yazar.',
        ],
        icon: Icons.vpn_key,
      ),
    ],
  );
}

Widget _policiesBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  final pendingApprovals = user.pendingApprovals
      .where((approval) => !approval.isResolved)
      .toList();

  return AdminInfoPage(
    title: 'Policies & Roles',
    subtitle: 'Rol oluşturma, izin atama ve süper admin nomination onayları.',
    menu: menu,
    ctx: ctx,
    sections: [
      AdminInfoSection(
        title: 'Rol Yönetimi',
        bullets: [
          'Yeni rol tanımlarken SQL policy tablosu güncellenir.',
          'Her değişimde claims_version artar ve Firebase custom claims güncellenir.',
        ],
        icon: Icons.admin_panel_settings,
      ),
      AdminInfoSection(
        title: 'Süper Admin Onay Akışı',
        bullets: pendingApprovals.isEmpty
            ? const ['Şu anda onay bekleyen bir nomination bulunmuyor.']
            : pendingApprovals
                  .map(
                    (approval) =>
                        'Talep: ${approval.id} · Gereken onay: ${approval.requiredApprovals} · Onaylayanlar: ${approval.approverUids.length}',
                  )
                  .toList(),
        icon: Icons.how_to_vote,
      ),
      const AdminInfoSection(
        title: 'İzin Şablonları',
        bullets: [
          'Operasyon, katalog ve destek admini için hazır preset setleri bulunur.',
          'Her preset, gerekirse tekil izinlerle override edilebilir.',
        ],
        icon: Icons.grid_view,
      ),
    ],
  );
}

Widget _auditBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Audit & Logs',
    subtitle: 'Tüm kritik işlemler için detaylı denetim izleri.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'Arama ve Filtre',
        bullets: [
          'Rol değişiklikleri, finansal işlemler ve login olayları filtrelenebilir.',
          'Export işlemi güvenli CSV/Parquet formatında yapılır.',
        ],
        icon: Icons.search,
      ),
      AdminInfoSection(
        title: 'İmpersonate View',
        bullets: [
          'Sadece görüntüleme amaçlıdır, işlem yapmaya izin vermez.',
          'İzleme sırasında tüm adımlar audit loguna ikinci kez yazılır.',
        ],
        icon: Icons.visibility,
      ),
    ],
  );
}

Widget _reportsBuilder(
  BuildContext context,
  User user,
  AdminMenuItemDefinition menu,
  AdminMenuAccessContext ctx,
) {
  return AdminInfoPage(
    title: 'Raporlama',
    subtitle: 'Operasyonel raporlar, KPI kartları ve dışa aktarma seçenekleri.',
    menu: menu,
    ctx: ctx,
    sections: const [
      AdminInfoSection(
        title: 'KPI Kartları',
        bullets: [
          'Satıcı onay süresi, ürün moderasyon SLA, finansal settlement süresi.',
          'Görünümler role göre filtrelenir.',
        ],
        icon: Icons.analytics,
      ),
      AdminInfoSection(
        title: 'Dışa Aktarım',
        bullets: [
          'Raporlar CSV veya BigQuery export seçeneklerine sahiptir.',
          'Export işlemleri audit loguna yazılır ve zaman damgası içerir.',
        ],
        icon: Icons.file_download,
      ),
    ],
  );
}
