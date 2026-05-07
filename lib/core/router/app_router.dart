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
import '../../features/settings/presentation/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // 인증 상태와 닉네임 상태를 모두 감시합니다.
  final authState = ref.watch(authStateProvider);
  final displayName = ref.watch(displayNameProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading || authState.hasError) return null;

      final user = authState.value;
      final isLoggedIn = user != null;
      
      // 익명 로그인인 경우, Firebase 유저 객체 혹은 앱 내부 프로바이더 중 
      // 어디에든 이름이 존재하면 준비된 것으로 간주합니다.
      final isProfileReady = !isLoggedIn || 
                            (user.displayName != null || displayName != null || !user.isAnonymous);
      
      final isLoggingIn = state.matchedLocation == '/login';

      if ((!isLoggedIn || !isProfileReady) && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && isProfileReady && isLoggingIn) {
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
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
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
