// lib/features/main_shell/screens/main_shell_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ranking_ground_v1/features/main_shell/providers/main_shell_provider.dart';
import 'package:ranking_ground_v1/features/main_shell/widgets/custom_bottom_nav_bar.dart';

import 'package:ranking_ground_v1/features/main_shell/screens/home_tab_screen.dart';
import 'package:ranking_ground_v1/features/game_hub/screens/game_ready_screen.dart';
import 'package:ranking_ground_v1/features/ranking/screens/school_ranking_screen.dart';
import 'package:ranking_ground_v1/features/ranking/screens/personal_ranking_screen.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  final List<Widget> _screens = const [
    HomeTabScreen(),
    GameReadyScreen(),
    SchoolRankingScreen(),
    PersonalRankingScreen(),
  ];

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return '랭킹그라운드 홈';
      case 1:
        return '게임 선택';
      case 2:
        return '학교 랭킹';
      case 3:
        return '개인 랭킹';
      default:
        return 'Ranking Ground';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainShellTabIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(currentIndex)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // ⭐️⭐️⭐️ 해결: .go를 .push로 변경하여 페이지를 교체하는 대신 위에 쌓도록 합니다. ⭐️⭐️⭐️
              context.push('/settings');
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(mainShellTabIndexProvider.notifier).state = index;
        },
      ),
    );
  }
}
