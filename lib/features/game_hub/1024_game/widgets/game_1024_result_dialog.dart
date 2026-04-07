// lib/features/game_hub/1024_game/widgets/game_1024_result_dialog.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/1024_game/providers/game_1024_game_provider.dart';
import 'package:ranking_ground_v1/features/main_shell/providers/main_shell_provider.dart';

import 'package:intl/intl.dart'; // 숫자 포맷팅을 위해 import

// --- 수정된 부분 ---
const String game1024Id = 'game_1024';

class Game1024ResultDialog extends ConsumerWidget {
  // ... (이하 코드는 변경 없음)
  final int finalScore;
  final int highestTile;
  final bool won;

  const Game1024ResultDialog({
    super.key,
    required this.finalScore,
    required this.highestTile,
    required this.won,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final formatter = NumberFormat('#,###');

    void restartGame() {
      Navigator.of(context).pop();
      Future.microtask(
          () => ref.read(game1024Provider.notifier).startNewGame());
    }

    void goToMainShell(int tabIndex) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ref.read(mainShellTabIndexProvider.notifier).state = tabIndex;
      context.go('/main_shell');
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(color: Colors.black.withAlpha(25)),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(60),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(won ? '🎉 You Won!' : '😢 Game Over',
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        Text('최고 타일: $highestTile',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigoAccent)),
                        const Divider(height: 30, thickness: 1),
                        userAsync.when(
                          data: (user) {
                            final best =
                                user?.bestScoresByGame[game1024Id] ?? 0;
                            // 🔽 [추가] 누적 점수를 가져오는 코드
                            final total =
                                user?.totalScoresByGame[game1024Id] ?? 0;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statColumn(
                                    Icons.flash_on_rounded,
                                    '이번 점수',
                                    formatter.format(
                                        finalScore)), // 이전에 수정한 숫자 포맷팅 적용
                                _statColumn(Icons.emoji_events_rounded, '최고 기록',
                                    formatter.format(best), // 이전에 수정한 숫자 포맷팅 적용
                                    isBest: true),
                                // 🔽 [추가] 누적 점수를 표시하는 위젯
                                _statColumn(Icons.leaderboard_rounded, '누적 합계',
                                    formatter.format(total)),
                              ],
                            );
                          },
                          loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: CircularProgressIndicator()),
                          error: (_, __) => const Text('점수 정보 로딩 실패',
                              style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _actionBtn(
                                icon: Icons.home_rounded,
                                label: '홈으로',
                                onTap: () => goToMainShell(0)),
                            _actionBtn(
                                icon: Icons.grid_view_rounded,
                                label: '게임 선택',
                                onTap: () => goToMainShell(1)),
                            _actionBtn(
                                icon: Icons.refresh_rounded,
                                label: '다시 시작',
                                onTap: restartGame,
                                isPrimary: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(IconData icon, String title, String value,
      {bool isBest = false}) {
    final color = isBest ? Colors.amber.shade700 : Colors.blueGrey.shade400;
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 6),
        Text(title,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isBest ? Colors.amber.shade800 : Colors.black87)),
      ],
    );
  }

  Widget _actionBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool isPrimary = false}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPrimary ? Colors.blueAccent : Colors.grey.shade200,
              boxShadow: [
                BoxShadow(
                    color: isPrimary
                        ? Colors.blueAccent.withAlpha(70)
                        : Colors.grey.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Icon(icon,
                size: 32, color: isPrimary ? Colors.white : Colors.black87),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700)),
      ],
    );
  }
}
