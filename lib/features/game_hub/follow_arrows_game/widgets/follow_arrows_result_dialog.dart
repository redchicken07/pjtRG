// lib/features/game_hub/follow_arrows_game/widgets/follow_arrows_result_dialog.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/follow_arrows_game/providers/follow_arrows_game_state_provider.dart';
import 'package:ranking_ground_v1/features/main_shell/providers/main_shell_provider.dart';
import 'package:intl/intl.dart';
import 'package:ranking_ground_v1/core/ads/ad_helper.dart';

// 이 게임의 고유 ID (UserModel의 맵 키와 일치)
const String followArrowsGameId = 'follow_arrows_game';

class FollowArrowsResultDialog extends ConsumerWidget {
  final int finalScore;
  final String gameEndReason;

  const FollowArrowsResultDialog({
    super.key,
    required this.finalScore,
    required this.gameEndReason,
  });

  String _getPrimaryMessage(int score) {
    if (score < 50) return "조금만 더 순발력을! 🏃‍♂️";
    if (score < 150) return "나쁘지 않아요! 👍";
    if (score < 300) return "정말 빨랐어요! ⚡";
    if (score < 500) return "대단한 순발력! 🚀";
    return "빛보다 빠른 손놀림! 🌟";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final formatter = NumberFormat('#,###');

    void restartGame() {
      Navigator.of(context).pop();
      Future.microtask(
          () => ref.read(followArrowsGameStateProvider.notifier).startGame());
    }

    void goToMainShell(int tabIndex) {
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
            child: Container(
              color: Colors.black.withAlpha(20),
            ),
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
                    padding: const EdgeInsets.only(
                        top: 24, left: 16, right: 16, bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '게임 결과',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getPrimaryMessage(finalScore),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange),
                        ),
                        if (gameEndReason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            gameEndReason,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const Divider(height: 30, thickness: 1),
                        userAsync.when(
                          data: (user) {
                            final best =
                                user?.bestScoresByGame[followArrowsGameId] ?? 0;
                            final total =
                                user?.totalScoresByGame[followArrowsGameId] ??
                                    0;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statColumn(Icons.flash_on_rounded, '이번 점수',
                                    formatter.format(finalScore)), // 포맷 적용
                                _statColumn(Icons.emoji_events_rounded, '최고 기록',
                                    formatter.format(best), // 포맷 적용
                                    isBest: true),
                                _statColumn(Icons.leaderboard_rounded, '누적 합계',
                                    formatter.format(total)), // 포맷 적용
                              ],
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: CircularProgressIndicator(),
                          ),
                          error: (_, __) => const Text(
                            '점수 정보를 불러올 수 없습니다.',
                            style: TextStyle(color: Colors.red),
                          ),
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
                  const BannerAdWidget(), // 신규 배너 광고 위젯으로 교체
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
                      : Colors.grey.withAlpha(100),
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
    );
  }
}
