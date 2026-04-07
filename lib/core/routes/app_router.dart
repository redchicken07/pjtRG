// lib/core/routes/app_router.dart
// 전체 교체 버전 (게임 라우트 포함 여부 선택 가능) / redirect 정리 / refreshListenable 간소화

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Auth
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/auth/screens/login_screen.dart';
import 'package:ranking_ground_v1/features/auth/screens/signup_screen.dart';

// Main Shell & Etc
import 'package:ranking_ground_v1/features/main_shell/screens/main_shell_screen.dart';
import 'package:ranking_ground_v1/features/main_shell/screens/settings_screen.dart';
import 'package:ranking_ground_v1/features/main_shell/widgets/notice_dialog_wrapper.dart';

// Game Play Screens (필요 없으면 주석 처리)
import 'package:ranking_ground_v1/features/game_hub/memory_maze_game/screens/memory_maze_play_screen.dart';
import 'package:ranking_ground_v1/features/game_hub/follow_arrows_game/screens/follow_arrows_play_screen.dart';
import 'package:ranking_ground_v1/features/game_hub/1024_game/screens/game_1024_play_screen.dart';

// -----------------------------------------------------------------------------
/// GoRouter가 Stream 변경을 감지해 refresh 하도록 도와주는 헬퍼 클래스
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// 앱 라우터 Provider (Riverpod)
final appRouterProvider = Provider<GoRouter>((ref) {
  // FirebaseAuth 상태 (AsyncValue)
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,

    // auth 변경 시 router refresh
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authServiceProvider).authStateChanges,
    ),

    redirect: (context, state) {
      final location = state.uri.toString();

      final isLoading = authState.isLoading;
      final isLoggedIn = authState.hasValue && authState.value != null;

      final atSplash = location == '/splash';
      final atAuth = location == '/login' || location == '/signup';

      // 1) 로딩 중이면 스플래시로 고정
      if (isLoading) {
        return atSplash ? null : '/splash';
      }

      // 2) 미로그인 상태: 비공개 경로 접근 시 로그인으로
      if (!isLoggedIn) {
        if (!atAuth && !atSplash) return '/login';
        if (atSplash) return '/login';
        return null; // 로그인/회원가입이면 그대로
      }

      // 3) 로그인 상태: 스플래시/로그인/회원가입에 있으면 메인으로
      if (isLoggedIn && (atSplash || atAuth)) {
        return '/main_shell';
      }

      return null; // 이동 없음
    },

    routes: <RouteBase>[
      // Splash
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (_, __) => const _SplashScreen(),
      ),

      // Auth
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (_, __) => const SignUpScreen(),
      ),

      // Main Shell
      GoRoute(
        path: '/main_shell',
        name: 'mainShell',
        builder: (_, __) => const NoticeDialogWrapper(
          child: MainShellScreen(),
        ),
      ),

      // Settings
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),

      // Game Play Only (필요 없으면 삭제/주석)
      GoRoute(
        path: '/game_hub/memory_maze_game/play',
        name: 'memoryMazeGamePlay',
        builder: (_, __) => const MemoryMazePlayScreen(),
      ),
      GoRoute(
        path: '/game_hub/follow_arrows_game/play',
        name: 'followArrowsGamePlay',
        builder: (_, __) => const FollowArrowsPlayScreen(),
      ),
      GoRoute(
        path: '/game_hub/1024_game/play',
        name: 'game1024Play',
        builder: (_, __) => const Game1024PlayScreen(),
      ),

      // 예시) 공지 페이지
      // GoRoute(
      //   path: '/notice',
      //   name: 'notice',
      //   builder: (_, __) => const NoticeScreen(),
      // ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('페이지 오류')),
      body: Center(
        child: Text(
          '''페이지를 찾을 수 없습니다.
${state.error}''', // <- 이렇게 수정
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
});

// 간단한 스플래시 화면 (필요 시 분리)
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
