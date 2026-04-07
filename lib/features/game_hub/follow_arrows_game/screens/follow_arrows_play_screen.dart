// lib/features/game_hub/follow_arrows_game/screens/follow_arrows_play_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';

import 'package:ranking_ground_v1/features/game_hub/follow_arrows_game/providers/follow_arrows_game_state_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/follow_arrows_game/models/arrow_direction.dart';
import 'package:ranking_ground_v1/features/game_hub/follow_arrows_game/models/game_mode.dart';
import 'package:ranking_ground_v1/features/game_hub/follow_arrows_game/widgets/follow_arrows_result_dialog.dart';

import 'package:intl/intl.dart'; // 숫자 포맷팅을 위해 import
import 'package:ranking_ground_v1/core/ads/ad_helper.dart';

const String followArrowsGameId = 'follow_arrows_game';

class FollowArrowsPlayScreen extends ConsumerStatefulWidget {
  const FollowArrowsPlayScreen({super.key});

  @override
  ConsumerState<FollowArrowsPlayScreen> createState() =>
      _FollowArrowsPlayScreenState();
}

class _FollowArrowsPlayScreenState
    extends ConsumerState<FollowArrowsPlayScreen> {
  bool _hasNavigatedToResult = false;

  final String _characterIdle = 'assets/character_idle.png';
  final String _characterLeft = 'assets/character_left.png';
  final String _characterRight = 'assets/character_right.png';
  final String _characterJump = 'assets/character_jump.png';
  final String _characterCrouch = 'assets/character_crouch.png';
  final String _gameAreaBackground = 'assets/background_arrows_follow.png';

  double _characterYOffset = 0;
  String _currentCharacterImage = 'assets/character_idle.png';
  bool _isCharacterAnimating = false;

  static const double defaultCharacterWidth = 70.0;
  static const double defaultCharacterHeight = 100.0;
  static const double characterWidthFactor = 0.15;
  static const double characterBottomPaddingFactor = 0.1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _currentCharacterImage = _characterIdle;
        ref.read(followArrowsGameStateProvider.notifier).startGame();
      }
    });
  }

  String getCharacterSprite(ArrowDirection? action) {
    if (action != null) {
      switch (action) {
        case ArrowDirection.left:
          return _characterLeft;
        case ArrowDirection.right:
          return _characterRight;
        case ArrowDirection.up:
          return _characterJump;
        case ArrowDirection.down:
          return _characterCrouch;
      }
    }
    return _characterIdle;
  }

  IconData getArrowIcon(ArrowDirection direction) {
    switch (direction) {
      case ArrowDirection.left:
        return Icons.arrow_back_rounded;
      case ArrowDirection.right:
        return Icons.arrow_forward_rounded;
      case ArrowDirection.up:
        return Icons.arrow_upward_rounded;
      case ArrowDirection.down:
        return Icons.arrow_downward_rounded;
    }
  }

  Color getArrowColor(bool isFirstCommand) {
    if (isFirstCommand) {
      return Colors.black87;
    }
    return Colors.blueGrey.shade300.withAlpha(200);
  }

  void _showGiveUpDialog(
      BuildContext context, FollowArrowsGameStateNotifier gameNotifier) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('게임 포기'),
        content: const Text('정말로 게임을 포기하시겠습니까?'),
        actions: [
          TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(dialogContext).pop()),
          TextButton(
            child: const Text('포기', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (mounted) {
                gameNotifier.giveUpGame();
              }
            },
          ),
        ],
      ),
    );
  }

  void _triggerCharacterAction(ArrowDirection action, bool isCorrect) {
    if (!mounted || _isCharacterAnimating) return;
    setState(() {
      _isCharacterAnimating = true;
      _currentCharacterImage = getCharacterSprite(action);
      double targetYOffset = 0;

      switch (action) {
        case ArrowDirection.left:
        case ArrowDirection.right:
          break;
        case ArrowDirection.up:
          const double moveDistanceVertical = 20.0;
          targetYOffset = -moveDistanceVertical;
          _currentCharacterImage = _characterJump;
          break;
        case ArrowDirection.down:
          const double moveDistanceVertical = 15.0;
          _currentCharacterImage = _characterCrouch;
          targetYOffset = moveDistanceVertical;
          break;
      }
      _characterYOffset = targetYOffset;
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _characterYOffset = 0;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isCharacterAnimating = false;
              _currentCharacterImage = _characterIdle;
            });
          }
        });
      }
    });
  }

  Widget _buildActionButton(FollowArrowsGameStateNotifier notifier,
      ArrowDirection direction, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ElevatedButton(
        onPressed: () {
          if (mounted &&
              ref.read(followArrowsGameStateProvider).awaitingInput &&
              !ref.read(followArrowsGameStateProvider).gameEnded) {
            notifier.playerInput(direction);
          }
        },
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(20),
          backgroundColor: Colors.white.withAlpha(230),
          foregroundColor: Colors.blueGrey.shade800,
          elevation: 3,
        ),
        child: Icon(icon, size: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(followArrowsGameStateProvider);
    final gameNotifier = ref.read(followArrowsGameStateProvider.notifier);
    final userProfileAsync = ref.watch(userProfileProvider);
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;

    final double currentCharacterWidth =
        screenWidth * _FollowArrowsPlayScreenState.characterWidthFactor;
    final double currentCharacterHeight = currentCharacterWidth *
        (defaultCharacterHeight / defaultCharacterWidth);
    final double characterCenterX = (screenWidth - currentCharacterWidth) / 2;

    final formatter = NumberFormat('#,###');

    ref.listen<FollowArrowsGameState>(followArrowsGameStateProvider,
        (previous, next) {
      final prevEnded = previous?.gameEnded ?? false;

      if (prevEnded && !next.gameEnded) {
        if (mounted) {
          setState(() {
            _hasNavigatedToResult = false;
          });
        }
      }

      if (next.gameEnded && !prevEnded && !_hasNavigatedToResult) {
        _hasNavigatedToResult = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showGeneralDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withAlpha(120),
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (context, anim1, anim2) {
              return FollowArrowsResultDialog(
                finalScore: next.score,
                gameEndReason: next.gameEndReason ?? "게임 종료!",
              );
            },
            transitionBuilder: (context, anim1, anim2, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
                child: ScaleTransition(
                  scale:
                      CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
                  child: child,
                ),
              );
            },
          );
        });
      }

      final prevPlayerAction = previous?.playerActionFeedback;
      if (next.playerActionFeedback != null &&
          next.playerActionFeedback != prevPlayerAction) {
        _triggerCharacterAction(
            next.playerActionFeedback!, next.lastAnswerCorrect ?? false);
      }
    });

    Widget characterVisual = Image.asset(_currentCharacterImage,
        key: ValueKey(_currentCharacterImage +
            DateTime.now().millisecondsSinceEpoch.toString()),
        width: currentCharacterWidth,
        height: currentCharacterHeight,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
            Icons.person_pin_circle_outlined,
            size: currentCharacterHeight,
            color: Colors.grey));

    Widget characterFinalDisplay = characterVisual;
    if (gameState.lastAnswerCorrect == false && _isCharacterAnimating) {
      characterFinalDisplay = TweenAnimationBuilder<double>(
        key: ValueKey(
            "shake_${gameState.playerActionFeedback.toString()}_${DateTime.now().millisecondsSinceEpoch}"),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        builder: (context, value, child) {
          final offsetVal = sin(value * pi * 8) * 6;
          final flashOpacity = sin(value * pi * 2);
          return Transform.translate(
            offset: Offset(offsetVal, 0),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                  Colors.red.withAlpha((flashOpacity.abs() * 180).toInt()),
                  BlendMode.srcIn),
              child: child!,
            ),
          );
        },
        child: Image.asset(_characterIdle,
            height: currentCharacterHeight,
            width: currentCharacterWidth,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(Icons.person,
                size: currentCharacterHeight, color: Colors.grey)),
      );
    }

    return PopScope<Object?>(
      canPop: gameState.gameEnded,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (!gameState.gameEnded && mounted) {
          _showGiveUpDialog(context, gameNotifier);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('좌우상하 순발력게임'),
          leading: !gameState.gameEnded
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: TextButton(
                      onPressed: () => _showGiveUpDialog(context, gameNotifier),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('포기',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                )
              : null,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      userProfileAsync.when(
                        data: (user) => Row(
                          children: [
                            Text(
                              'BEST: ${formatter.format(user?.bestScoresByGame[followArrowsGameId] ?? 0)}',
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
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: gameState.timeLeft /
                        10, // This needs to be adjusted according to the initial time value in the provider
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "⏱ ${gameState.timeLeft.toStringAsFixed(1)}초",
                    style: textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(200),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black54, width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          // --- 수정: `indexOf` 버그 수정 ---
                          children: gameState.commandQueue
                              .asMap()
                              .entries
                              .map((entry) {
                            final int index = entry.key;
                            final ArrowDirection dir = entry.value;
                            final bool isFirst = index == 0;

                            final double currentIconSize =
                                isFirst ? 42.0 : 30.0;
                            final icon = Icon(
                              getArrowIcon(dir),
                              size: currentIconSize,
                              color: getArrowColor(isFirst),
                            );

                            if (isFirst) {
                              return Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2.0),
                                padding: const EdgeInsets.all(4.0),
                                decoration: BoxDecoration(
                                  color: Colors.yellow.withAlpha(100),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.amber.shade600, width: 2.0),
                                ),
                                child: icon,
                              );
                            } else {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: icon,
                              );
                            }
                          }).toList(),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: (gameState.currentMode == GameMode.normal
                                    ? Colors.blueAccent.shade700
                                    : Colors.redAccent.shade400)
                                .withAlpha(230),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withAlpha(100),
                                  blurRadius: 4,
                                  offset: const Offset(1, 2))
                            ]),
                        child: Text(
                          gameState.currentMode == GameMode.normal
                              ? "일반 모드"
                              : "반대 모드",
                          style: textTheme.labelLarge?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: Image.asset(
                        _gameAreaBackground,
                        fit: BoxFit.cover,
                        alignment: Alignment.bottomCenter,
                        errorBuilder: (context, error, stackTrace) {
                          if (kDebugMode) {
                            print("Error loading game background: $error");
                          }
                          return Container(color: Colors.blueGrey.shade100);
                        },
                      ),
                    ),
                  ),
                  if (gameState.modeChangeOverlayText != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withAlpha(160),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(230),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                gameState.modeChangeOverlayText!,
                                style: textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: characterCenterX,
                    bottom: (MediaQuery.of(context).size.height * 0.4) *
                            characterBottomPaddingFactor -
                        _characterYOffset,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      transform:
                          Matrix4.translationValues(0, _characterYOffset, 0),
                      transformAlignment: Alignment.bottomCenter,
                      width: currentCharacterWidth,
                      height: currentCharacterHeight,
                      child: characterFinalDisplay,
                    ),
                  ),
                ],
              ),
            ),
            if (!gameState.gameEnded)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
                child: AbsorbPointer(
                  absorbing: !gameState.awaitingInput,
                  child: Opacity(
                    opacity: gameState.awaitingInput ? 1.0 : 0.5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(gameNotifier, ArrowDirection.up,
                            Icons.keyboard_arrow_up_rounded),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionButton(
                                gameNotifier,
                                ArrowDirection.left,
                                Icons.keyboard_arrow_left_rounded),
                            SizedBox(width: currentCharacterWidth * 0.8),
                            _buildActionButton(
                                gameNotifier,
                                ArrowDirection.right,
                                Icons.keyboard_arrow_right_rounded),
                          ],
                        ),
                        _buildActionButton(gameNotifier, ArrowDirection.down,
                            Icons.keyboard_arrow_down_rounded),
                      ],
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 180),
            const BannerAdWidget(), // 신규 배너 광고 위젯으로 교체
          ],
        ),
      ),
    );
  }
}
