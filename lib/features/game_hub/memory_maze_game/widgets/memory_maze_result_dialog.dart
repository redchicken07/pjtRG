// lib/features/game_hub/memory_maze_game/widgets/memory_maze_result_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/memory_maze_game/providers/memory_maze_provider.dart';
import 'package:ranking_ground_v1/features/main_shell/providers/main_shell_provider.dart';

class MemoryMazeResultDialog extends ConsumerWidget {
  final int finalScore;
  final int finalRound;

  const MemoryMazeResultDialog(
      {super.key, required this.finalScore, required this.finalRound});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final formatter = NumberFormat('#,###');

    void restartGame() {
      Navigator.of(context).pop();
      ref.read(memoryMazeProvider.notifier).startGame();
    }

    void goToMainShell(int tabIndex) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ref.read(mainShellTabIndexProvider.notifier).state = tabIndex;
      context.go('/main_shell');
    }

    // ✅ [개선] 위젯이 자체적으로 스크롤을 처리하도록 SingleChildScrollView 내장
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((255 * 0.15).round()),
                blurRadius: 25,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉 게임 결과 🎉',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('최종 라운드: $finalRound',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigoAccent)),
            const Divider(height: 30, thickness: 1),
            userAsync.when(
              data: (user) {
                final best = user?.bestScoresByGame[memoryMazeGameId] ?? 0;
                final total = user?.totalScoresByGame[memoryMazeGameId] ?? 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statColumn(Icons.flash_on_rounded, '이번 점수',
                        formatter.format(finalScore)),
                    _statColumn(Icons.emoji_events_rounded, '최고 기록',
                        formatter.format(best),
                        isBest: true),
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
                    semanticLabel: '홈 화면으로 이동',
                    onTap: () => goToMainShell(0)),
                _actionBtn(
                    icon: Icons.grid_view_rounded,
                    label: '게임 선택',
                    semanticLabel: '게임 선택 화면으로 이동',
                    onTap: () => goToMainShell(1)),
                _actionBtn(
                    icon: Icons.refresh_rounded,
                    label: '다시 시작',
                    semanticLabel: '게임 다시 시작',
                    onTap: restartGame,
                    isPrimary: true),
              ],
            ),
          ],
        ),
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

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    String? semanticLabel, // ✅ [개선] 접근성을 위한 semanticLabel 추가
  }) {
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: Column(
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
                        ? Colors.blueAccent.withAlpha((255 * 0.3).round())
                        : Colors.grey.withAlpha((255 * 0.4).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
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
      ),
    );
  }
}
