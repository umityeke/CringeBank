import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app/presentation/widgets/app_shell.dart';
import '../../features/feed/presentation/pages/feed_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/store/presentation/pages/store_page.dart';
import '../../features/store/presentation/pages/store_product_detail_page.dart';
import 'package:cringebank/models/store_product.dart' as store_model;
import '../../features/wallet/presentation/pages/wallet_page.dart';
import '../../features/login/application/login_providers.dart';
import '../../core/session/session_providers.dart';
import '../../features/onboarding/presentation/pages/registration_flow_page.dart';
import '../../features/onboarding/application/registration_providers.dart';
import '../../features/login/presentation/pages/login_flow_page.dart';
import '../../features/auth/presentation/pages/modern_auth_page.dart';

enum AppRoute { feed, store, wallet, notifications, profile }

final appRouterProvider = Provider<GoRouter>((ref) {
  // ignore: unused_local_variable
  final restoration = ref.watch(registrationRestorationProvider);
  // ignore: unused_local_variable
  final requiresRegistration = ref.watch(registrationRequiredProvider);
  // ignore: unused_local_variable
  final isAuthenticated = ref.watch(loginAuthenticatedProvider);
  // ignore: unused_local_variable
  final sessionHydrated = ref.watch(sessionHydratedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (!restoration.hasValue) {
        return null;
      }

      final isModernAuthRoute = state.uri.path == '/modern-auth';

      if (!sessionHydrated) {
        return state.uri.path == '/login' || isModernAuthRoute ? null : '/login';
      }

      final isRegisterRoute = state.uri.path == '/register';
      final isLoginRoute = state.uri.path == '/login';

      if (requiresRegistration && !isRegisterRoute) {
        return '/register';
      }

      if (!requiresRegistration && isRegisterRoute) {
        return AppRoute.feed.path;
      }

      if (!isAuthenticated && !isLoginRoute && !isRegisterRoute && !isModernAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && (isLoginRoute || isModernAuthRoute)) {
        return AppRoute.feed.path;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/register',
        name: 'registration',
        pageBuilder: (context, state) => const NoTransitionPage(child: RegistrationFlowPage()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => const NoTransitionPage(child: LoginFlowPage()),
      ),
      GoRoute(
        path: '/modern-auth',
        name: 'modern-auth',
        pageBuilder: (context, state) => const NoTransitionPage(child: ModernAuthPage()),
      ),
      GoRoute(
        path: '/',
  redirect: (_, state) => AppRoute.feed.path,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.feed.path,
                name: AppRoute.feed.name,
                pageBuilder: (context, state) => const NoTransitionPage(child: FeedPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.store.path,
                name: AppRoute.store.name,
                pageBuilder: (context, state) => const NoTransitionPage(child: StorePage()),
                routes: [
                  GoRoute(
                    path: ':productId',
                    name: 'store-product-detail',
                    pageBuilder: (context, state) {
                      final productId = state.pathParameters['productId']!;
            final product = state.extra is store_model.StoreProduct
              ? state.extra as store_model.StoreProduct
              : null;
                      return MaterialPage<void>(
                        key: state.pageKey,
                        child: StoreProductDetailPage(productId: productId, initialProduct: product),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.wallet.path,
                name: AppRoute.wallet.name,
                pageBuilder: (context, state) => const NoTransitionPage(child: WalletPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.notifications.path,
                name: AppRoute.notifications.name,
                pageBuilder: (context, state) => const NoTransitionPage(child: NotificationsPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.profile.path,
                name: AppRoute.profile.name,
                pageBuilder: (context, state) => const NoTransitionPage(child: ProfilePage()),
              ),
            ],
          ),
        ],
      ),
    ],
    observers: [
      _RouteObserver(ref),
    ],
  );
});

extension on AppRoute {
  String get path {
    return switch (this) {
      AppRoute.feed => '/feed',
      AppRoute.store => '/store',
      AppRoute.wallet => '/wallet',
      AppRoute.notifications => '/notifications',
      AppRoute.profile => '/profile',
    };
  }
}

class _RouteObserver extends NavigatorObserver {
  _RouteObserver(this._ref);

  final Ref _ref;

  void _handleRouteChange([Route<dynamic>? route]) {
    final navigatorState = navigator ?? route?.navigator;
    if (navigatorState == null || !navigatorState.mounted) {
      return;
    }

    unawaited(
      _ref.read(sessionControllerProvider.notifier).expireIfNeeded().then((expired) {
        if (!expired || !navigatorState.mounted) {
          return;
        }
        GoRouter.of(navigatorState.context).go('/login');
      }),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _handleRouteChange(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _handleRouteChange(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _handleRouteChange(previousRoute);
  }
}
