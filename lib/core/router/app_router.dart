import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_scaffold.dart';
import '../../features/map/presentation/map_home_screen.dart';
import '../../features/gifticon/presentation/gifticon_list_screen.dart';
import '../../features/gifticon/presentation/gifticon_detail_screen.dart';
import '../../features/gifticon/presentation/gifticon_manual_add_screen.dart';
import '../../features/gifticon/domain/models/gifticon_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
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
