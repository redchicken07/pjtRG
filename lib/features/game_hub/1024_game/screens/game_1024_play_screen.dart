// lib/features/game_hub/1024_game/screens/game_1024_play_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ranking_ground_v1/core/ads/ad_helper.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/1024_game/models/game_1024_constants.dart';
import 'package:ranking_ground_v1/features/game_hub/1024_game/models/game_1024_model.dart';
import 'package:ranking_ground_v1/features/game_hub/1024_game/providers/game_1024_game_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/1024_game/widgets/game_1024_result_dialog.dart';

class Game1024PlayScreen extends ConsumerStatefulWidget {
  const Game1024PlayScreen({super.key});

  @override
  ConsumerState<Game1024PlayScreen> createState() => _Game1024PlayScreenState();
}

class _Game1024PlayScreenState extends ConsumerState<Game1024PlayScreen> {
  // ◀️ [수정] 클래스 멤버 변수들을 여기에 모두 선언
  static const double _gridPadding = 8.0;
  late final int _gridSize;
  bool _hasNavigatedToResult = false;
  List<List<TileModel?>> _previousGrid = [];

  @override
  void initState() {
    super.initState();
    _gridSize = GameConstants1024.gridSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(game1024Provider.notifier).startNewGame();
        _previousGrid = ref.read(game1024Provider).grid;
      }
    });
  }

  void _showGiveUpDialog(BuildContext context) {
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
              ref.read(game1024Provider.notifier).giveUpAndEndGame();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showResultDialog(BuildContext context, GameState next) async {
    if (!context.mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => Game1024ResultDialog(
        finalScore: next.score,
        highestTile: next.highestTileValue,
        won: next.highestTileValue >= GameConstants1024.targetTile,
      ),
    );
  }

  // ◀️ [수정] _buildTiles 메서드를 State 클래스 안으로 이동
  List<Widget> _buildTiles(GameState gameState, double tileSize) {
    final List<Widget> tiles = [];
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        final tile = gameState.grid[r][c];
        if (tile != null) {
          bool isNew =
              !_previousGrid.any((row) => row.any((t) => t?.id == tile.id));
          tiles.add(
            AnimatedPositioned(
              key: ValueKey(tile.id),
              duration: const Duration(milliseconds: 150),
              top: r * (tileSize + _gridPadding) + _gridPadding,
              left: c * (tileSize + _gridPadding) + _gridPadding,
              child: _AnimatedTileWidget(
                key: ValueKey('tile-${tile.id}'),
                tile: tile,
                tileSize: tileSize,
                isNew: isNew,
              ),
            ),
          );
        }
      }
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(game1024Provider);
    final gameNotifier = ref.read(game1024Provider.notifier);
    final userProfileAsync = ref.watch(userProfileProvider);
    final textTheme = Theme.of(context).textTheme;
    final bool isGameEnded = gameState.gameStatus != GameStatus1024.playing;
    final formatter = NumberFormat('#,###');

    ref.listen<GameState>(game1024Provider, (previous, next) {
      // 1) 이전 그리드 보존
      if (previous != null) {
        setState(() {
          _previousGrid = previous.grid;
        });
      }

      final prevStatus = previous?.gameStatus ?? GameStatus1024.playing;
      final currStatus = next.gameStatus;

      // 2) 재시작 시 플래그 리셋
      if ((prevStatus == GameStatus1024.gameOver ||
              prevStatus == GameStatus1024.won) &&
          currStatus == GameStatus1024.playing) {
        if (mounted) {
          setState(() {
            _hasNavigatedToResult = false;
          });
        }
      }

      // 3) 게임 종료 후 결과 다이얼로그 한 번만 띄우기
      if (currStatus != GameStatus1024.playing && !_hasNavigatedToResult) {
        _hasNavigatedToResult = true;

        // 프레임 렌더링 완료 후 안전하게 다이얼로그 호출
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showResultDialog(context, next);
          }
        });
      }
    });

    // ◀️ [수정] 변수 선언 위치 및 중복 제거
    final screenSize = MediaQuery.of(context).size;
    final gameAreaSide = screenSize.width - 32;
    final tileSize =
        (gameAreaSide - (_gridPadding * (_gridSize + 1))) / _gridSize;

    return PopScope(
      canPop: isGameEnded,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (!isGameEnded && mounted) {
          _showGiveUpDialog(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8EF),
        appBar: AppBar(
          title: const Text('1024 Puzzle'),
          centerTitle: true,
          leading: !isGameEnded
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: TextButton(
                      onPressed: () => _showGiveUpDialog(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    userProfileAsync.when(
                      data: (user) => Row(
                        children: [
                          Text(
                            'BEST: ${formatter.format(user?.bestScoresByGame['game_1024'] ?? 0)}',
                            style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '🏆 ${formatter.format(gameState.score)}',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('점수 로딩 실패'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  LinearProgressIndicator(
                    value: (gameState.remainingTime /
                            GameConstants1024.initialTime)
                        .clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 4),
                  Text('⏱️ ${gameState.remainingTime.toStringAsFixed(1)} 초',
                      style: textTheme.titleLarge?.copyWith(fontSize: 18)),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! < -100) {
                    gameNotifier.move(SwipeDirection.up);
                  }
                  if (details.primaryVelocity! > 100) {
                    {
                      gameNotifier.move(SwipeDirection.down);
                    }
                  }
                },
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! < -100) {
                    gameNotifier.move(SwipeDirection.left);
                  }
                  if (details.primaryVelocity! > 100) {
                    gameNotifier.move(SwipeDirection.right);
                  }
                },
                child: Container(
                  width: gameAreaSide,
                  height: gameAreaSide,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(_gridPadding),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _gridSize,
                          mainAxisSpacing: _gridPadding,
                          crossAxisSpacing: _gridPadding,
                        ),
                        itemCount: _gridSize * _gridSize,
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                      ..._buildTiles(gameState, tileSize),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              const BannerAdWidget(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedTileWidget extends StatefulWidget {
  final TileModel tile;
  final double tileSize;
  final bool isNew;
  const _AnimatedTileWidget(
      {required this.tile,
      required this.tileSize,
      required this.isNew,
      super.key});

  @override
  State<_AnimatedTileWidget> createState() => _AnimatedTileWidgetState();
}

class _AnimatedTileWidgetState extends State<_AnimatedTileWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
        value: widget.isNew ? 0.0 : 1.0);
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    if (widget.isNew || widget.tile.status == TileMergeStatus.merged) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorForValue(int value) {
    switch (value) {
      case 2:
        return const Color(0xfffce4ec);
      case 4:
        return const Color(0xffffe0b2);
      case 8:
        return const Color(0xfffff9c4);
      case 16:
        return const Color(0xffdcedc8);
      case 32:
        return const Color(0xffb2ebf2);
      case 64:
        return const Color(0xffb3e5fc);
      case 128:
        return const Color(0xffc5cae9);
      case 256:
        return const Color(0xffd1c4e9);
      case 512:
        return const Color(0xfff8bbd0);
      case 1024:
        return const Color(0xffe1bee7);
      case 2048:
        return const Color(0xff3c3a32);
      default:
        return Colors.grey.shade800;
    }
  }

  double _fontSizeForValue(int value) {
    if (value >= 1000) return 28;
    if (value >= 100) return 36;
    if (value >= 10) return 44;
    return 52;
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: widget.tileSize,
        height: widget.tileSize,
        decoration: BoxDecoration(
            color: _colorForValue(widget.tile.value),
            borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text(
          '${widget.tile.value}',
          style: TextStyle(
            fontSize: _fontSizeForValue(widget.tile.value),
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
