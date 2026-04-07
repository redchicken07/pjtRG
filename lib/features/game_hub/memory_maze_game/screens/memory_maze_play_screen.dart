// lib/features/game_hub/memory_maze_game/screens/memory_maze_play_screen.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ranking_ground_v1/core/ads/ad_helper.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/memory_maze_game/providers/memory_maze_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/memory_maze_game/widgets/memory_maze_result_dialog.dart';

class MemoryMazePlayScreen extends ConsumerStatefulWidget {
  const MemoryMazePlayScreen({super.key});

  @override
  ConsumerState<MemoryMazePlayScreen> createState() =>
      _MemoryMazePlayScreenState();
}

class _MemoryMazePlayScreenState extends ConsumerState<MemoryMazePlayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memoryMazeProvider.notifier).startGame();
    });
  }

  void _showGiveUpDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('게임 포기'),
        content: const Text('정말로 게임을 포기하시겠습니까?'),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: const Text('포기', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(memoryMazeProvider.notifier).giveUpAndEndGame();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shellState = ref.watch(memoryMazeProvider.select((s) => (
          round: s.round,
          gamePhase: s.gamePhase,
          wallHitFeedback: s.wallHitFeedback,
        )));
    final notifier = ref.read(memoryMazeProvider.notifier);
    final isGameEnded = shellState.gamePhase == GamePhase.gameOver;
    final showGiveUpButton = shellState.gamePhase != GamePhase.gameOver &&
        shellState.gamePhase != GamePhase.roundFail;

    ref.listen<GamePhase>(
      memoryMazeProvider.select((s) => s.gamePhase),
      (prev, next) {
        if (next != GamePhase.gameOver || prev == GamePhase.gameOver) return;
        if (!mounted) return;
        final finalState = ref.read(memoryMazeProvider);
        showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withAlpha((255 * 0.4).round()),
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, anim1, anim2) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 380,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: MemoryMazeResultDialog(
                  finalScore: finalState.score,
                  finalRound: finalState.round,
                ),
              ),
            );
          },
          transitionBuilder: (context, anim, secondAnim, child) {
            return BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 4 * anim.value, sigmaY: 4 * anim.value),
              child: FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale:
                      CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  child: child,
                ),
              ),
            );
          },
        );
      },
    );

    return PopScope(
      canPop: isGameEnded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (shellState.gamePhase == GamePhase.roundFail) {
            ref.read(memoryMazeProvider.notifier).giveUpAndEndGame();
          } else {
            _showGiveUpDialog(context, ref);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('메모리 미로 (Round ${shellState.round})'),
          leading: showGiveUpButton
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: TextButton(
                      onPressed: () => _showGiveUpDialog(context, ref),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('포기',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                )
              : null,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                _HeaderDisplay(),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: shellState.wallHitFeedback
                        ? Colors.red.withAlpha((255 * 0.3).round())
                        : Colors.transparent,
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity!.abs() > 200) {
                          notifier.movePlayer(
                              Point(details.primaryVelocity! > 0 ? 1 : -1, 0));
                        }
                      },
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity!.abs() > 200) {
                          notifier.movePlayer(
                              Point(0, details.primaryVelocity! > 0 ? 1 : -1));
                        }
                      },
                      child: Center(
                        child:
                            AspectRatio(aspectRatio: 1.0, child: _MazeGrid()),
                      ),
                    ),
                  ),
                ),
                const BannerAdWidget(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderDisplay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memoryMazeProvider.select((s) => (
          gamePhase: s.gamePhase,
          score: s.score,
          memoryTimeTotal: s.memoryTimeTotal,
          memoryTimeLeft: s.memoryTimeLeft,
          playTimeTotal: s.playTimeTotal,
          playTimeLeft: s.playTimeLeft,
        )));
    final user = ref.watch(userProfileProvider).asData?.value;
    final formatter = NumberFormat('#,###');
    final textTheme = Theme.of(context).textTheme;
    final totalTime = state.memoryTimeTotal + state.playTimeTotal;
    final leftTime = state.memoryTimeLeft + state.playTimeLeft;
    final timerValue = totalTime > 0 ? leftTime / totalTime : 0.0;
    final timerText = state.gamePhase == GamePhase.memorizing
        ? '바로 출발 가능! 총 ${leftTime.toStringAsFixed(1)}초'
        : '남은 시간 ${leftTime.toStringAsFixed(1)}초';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                  'BEST: ${formatter.format(user?.bestScoresByGame[memoryMazeGameId] ?? 0)}',
                  style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(width: 16),
              Text('🏆 ${formatter.format(state.score)}',
                  style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.amber)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: timerValue.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          Text('⏱️ $timerText',
              style: textTheme.titleLarge?.copyWith(fontSize: 18)),
        ],
      ),
    );
  }
}

class _MazeGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memoryMazeProvider.select((s) => (
          maze: s.maze,
          gamePhase: s.gamePhase,
          playerPosition: s.playerPosition,
          finishPosition: s.finishPosition,
        )));
    final maze = state.maze;
    if (maze.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        // 1. 미로 배경 그리기
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: maze[0].length),
          itemCount: maze.length * maze[0].length,
          itemBuilder: (context, index) {
            final x = index % maze[0].length;
            final y = index ~/ maze[0].length;
            final tileType = maze[y][x];
            return _buildTile(
                tileType, state.gamePhase == GamePhase.memorizing);
          },
        ),
        // 2. 플레이어, 도착점 등 오버레이 아이템 그리기
        ..._buildOverlay(
          context: context,
          maze: maze,
          playerPosition: state.playerPosition,
          finishPosition: state.finishPosition,
          gamePhase: state.gamePhase,
        ),
        // 3. 라운드 성공/실패 시 전체 화면을 덮는 오버레이
        if (state.gamePhase == GamePhase.roundSuccess ||
            state.gamePhase == GamePhase.roundFail)
          GestureDetector(
            onTap: state.gamePhase == GamePhase.roundSuccess
                ? ref.read(memoryMazeProvider.notifier).nextRound
                : ref.read(memoryMazeProvider.notifier).giveUpAndEndGame,
            child: Container(
              color: Colors.black.withAlpha((255 * 0.7).round()),
              child: Center(
                child: Text(
                  state.gamePhase == GamePhase.roundSuccess
                      ? '성공!\n탭하여 다음 라운드로'
                      : '실패!\n탭하여 종료',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 플레이어, 도착점 등 게임 플레이 중 보이는 아이템들
  List<Widget> _buildOverlay({
    required BuildContext context,
    required List<List<TileType>> maze,
    required MazePoint playerPosition,
    required MazePoint finishPosition,
    required GamePhase gamePhase,
  }) {
    if (maze.isEmpty) return [];
    final availableWidth = MediaQuery.of(context).size.width - 32;
    final size = availableWidth / maze[0].length;

    return [
      // 플레이어 위치 (파란색 원)
      AnimatedPositioned(
        duration: const Duration(milliseconds: 150),
        top: playerPosition.y * size,
        left: playerPosition.x * size,
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.15),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
            // 게임 시작 시(기억 단계)에만 "Start" 텍스트 표시
            child: gamePhase == GamePhase.memorizing
                ? Text(
                    "Start",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: size * 0.25,
                    ),
                  )
                : null,
          ),
        ),
      ),
      // 도착점 위치 (깃발)
      Positioned(
        top: finishPosition.y * size,
        left: finishPosition.x * size,
        child: Padding(
          padding: EdgeInsets.all(size * 0.1),
          child: Icon(
            Icons.flag,
            color: Colors.redAccent,
            size: size * 0.8,
          ),
        ),
      ),
    ];
  }

  // 각 미로 타일의 배경 (기억 단계에서만 보임)
  Widget _buildTile(TileType type, bool isMemorizing) {
    if (!isMemorizing) {
      // 기억 단계가 아니면 모두 어두운 회색으로 표시
      return Container(
          decoration: BoxDecoration(
              color: Colors.grey.shade800,
              border: Border.all(
                  color: Colors.black.withAlpha((255 * 0.5).round()),
                  width: 0.5)));
    }

    // 기억 단계일 때 각 타일 타입에 따라 배경색과 아이콘 결정
    Color color;
    switch (type) {
      case TileType.path:
      case TileType.start: // 출발점도 일반 길과 같은 배경
      case TileType.finish: // 도착점도 일반 길과 같은 배경
        color = Colors.grey.shade300;
        break;
      case TileType.wall:
        color = Colors.black87;
        break;
    }

    return Container(
      decoration: BoxDecoration(
          color: color, border: Border.all(color: Colors.black26, width: 0.5)),
    );
  }
}
