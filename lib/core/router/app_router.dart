import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_scaffold.dart';
import '../../features/map/presentation/map_home_screen.dart';
import '../../features/gifticon/presentation/gifticon_list_screen.dart';
import '../../features/gifticon/presentation/gifticon_detail_screen.dart';
import '../../features/gifticon/presentation/gifticon_manual_add_screen.dart';
import '../../features/gifticon/domain/models/gifticon_model.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // 인증 상태를 감시합니다.
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // 로딩 중이거나 에러 발생 시 리다이렉트를 수행하지 않습니다.
      if (authState.isLoading || authState.hasError) return null;

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      // 로그인이 되어있지 않은데 로그인 페이지가 아니라면 로그인 페이지로 이동합니다.
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // 로그인이 되어있는데 로그인 페이지에 머물러 있다면 메인 페이지로 이동합니다.
      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MapHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/wallet',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GifticonListScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/wallet/detail',
        builder: (context, state) {
          final gifticon = state.extra as GifticonModel;
          return GifticonDetailScreen(gifticon: gifticon);
        },
      ),
      GoRoute(
        path: '/wallet/add-manual',
        builder: (context, state) => const GifticonManualAddScreen(),
      ),
    ],
  );
});
