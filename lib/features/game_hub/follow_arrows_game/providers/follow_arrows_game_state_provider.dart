// lib/features/game_hub/follow_arrows_game/providers/follow_arrows_game_state_provider.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ranking_ground_v1/core/ads/ad_helper.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/data/models/user_model.dart';
import 'package:ranking_ground_v1/features/auth/services/auth_service.dart';
import 'package:ranking_ground_v1/features/game_hub/follow_arrows_game/models/arrow_direction.dart';
import 'package:ranking_ground_v1/features/game_hub/follow_arrows_game/models/game_mode.dart';

const double faInitialTimeLimitSeconds = 7.5;
const double faMaxTimeLimitSeconds = 10.0;
const double faTimeBonusPerCorrect = 0.75;
const double faTimePenaltyPerWrong = 2.0;
const int previewQueueSize = 5;
const Duration faIncorrectFeedbackDuration = Duration(milliseconds: 400);

const int initialNormalModeCount = 15;

class FollowArrowsGameState {
  final double timeLeft;
  final int score;
  final int combo;
  final List<ArrowDirection> commandQueue;
  final GameMode currentMode;
  final bool gameEnded;
  final String? gameEndReason;
  final String? modeChangeOverlayText;
  final ArrowDirection? playerActionFeedback;
  final bool? lastAnswerCorrect;
  final int currentModeBonusPoints;
  final bool awaitingInput;
  final int correctAnswersCount;

  FollowArrowsGameState({
    this.timeLeft = faInitialTimeLimitSeconds,
    this.score = 0,
    this.combo = 0,
    this.commandQueue = const [],
    this.currentMode = GameMode.normal,
    this.gameEnded = false,
    this.gameEndReason,
    this.modeChangeOverlayText,
    this.playerActionFeedback,
    this.lastAnswerCorrect,
    this.currentModeBonusPoints = 0,
    this.awaitingInput = true,
    this.correctAnswersCount = 0,
  });

  FollowArrowsGameState copyWith({
    double? timeLeft,
    int? score,
    int? combo,
    List<ArrowDirection>? commandQueue,
    GameMode? currentMode,
    bool? gameEnded,
    String? gameEndReason,
    String? modeChangeOverlayText,
    bool clearModeChangeOverlay = false,
    ArrowDirection? playerActionFeedback,
    bool clearPlayerActionFeedback = false,
    bool? lastAnswerCorrect,
    bool clearLastAnswerCorrect = false,
    int? currentModeBonusPoints,
    bool? awaitingInput,
    int? correctAnswersCount,
  }) {
    return FollowArrowsGameState(
      timeLeft: timeLeft ?? this.timeLeft,
      score: score ?? this.score,
      combo: combo ?? this.combo,
      commandQueue: commandQueue ?? this.commandQueue,
      currentMode: currentMode ?? this.currentMode,
      gameEnded: gameEnded ?? this.gameEnded,
      gameEndReason: gameEndReason ?? this.gameEndReason,
      modeChangeOverlayText: clearModeChangeOverlay
          ? null
          : modeChangeOverlayText ?? this.modeChangeOverlayText,
      playerActionFeedback: clearPlayerActionFeedback
          ? null
          : playerActionFeedback ?? this.playerActionFeedback,
      lastAnswerCorrect: clearLastAnswerCorrect
          ? null
          : lastAnswerCorrect ?? this.lastAnswerCorrect,
      currentModeBonusPoints:
          currentModeBonusPoints ?? this.currentModeBonusPoints,
      awaitingInput: awaitingInput ?? this.awaitingInput,
      correctAnswersCount: correctAnswersCount ?? this.correctAnswersCount,
    );
  }
}

class FollowArrowsGameStateNotifier
    extends StateNotifier<FollowArrowsGameState> {
  Timer? _gameTimer;
  final Random _random = Random();
  final Ref _ref;
  int _nextModeToggleCount = initialNormalModeCount;
  int _modeChangeCount = 0;

  FollowArrowsGameStateNotifier(this._ref) : super(FollowArrowsGameState());

  int _generateWeightedRandomInterval() {
    final List<int> weightedList = [
      1,
      1,
      1,
      1,
      1,
      2,
      2,
      2,
      2,
      3,
      3,
      3,
      4,
      4,
      5,
      5,
      6,
      7,
      8,
      9,
      10
    ];
    return weightedList[_random.nextInt(weightedList.length)];
  }

  void startGame() {
    if (kDebugMode) {
      print("FollowArrowsGame: Starting game...");
    }
    _gameTimer?.cancel();
    _nextModeToggleCount = initialNormalModeCount;
    _modeChangeCount = 0;

    List<ArrowDirection> initialCommands = [];
    for (int i = 0; i < previewQueueSize; i++) {
      initialCommands.add(_generateRandomDirection());
    }

    state = FollowArrowsGameState(
        commandQueue: initialCommands,
        currentModeBonusPoints: 0,
        awaitingInput: true,
        correctAnswersCount: 0);
    _startMainTimer();
  }

  void _startMainTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || state.gameEnded) {
        timer.cancel();
        return;
      }
      if (state.timeLeft > 0) {
        double newTime = state.timeLeft - 0.1;
        if (newTime < 0) {
          newTime = 0;
        }
        if (mounted) {
          state = state.copyWith(timeLeft: newTime);
        }
      }
      if (state.timeLeft <= 0 && !state.gameEnded) {
        timer.cancel();
        _endGame(reason: "시간 종료!", userGaveUp: false);
      }
    });
  }

  ArrowDirection _generateRandomDirection() {
    return ArrowDirection.values[_random.nextInt(ArrowDirection.values.length)];
  }

  void _updateCommandQueue() {
    if (!mounted || state.gameEnded) {
      return;
    }
    List<ArrowDirection> newQueue = List.from(state.commandQueue);
    if (newQueue.isNotEmpty) {
      newQueue.removeAt(0);
    }
    while (newQueue.length < previewQueueSize) {
      newQueue.add(_generateRandomDirection());
    }
    if (mounted) {
      state = state.copyWith(
          commandQueue: newQueue,
          clearPlayerActionFeedback: true,
          clearLastAnswerCorrect: true,
          awaitingInput: true);
    }
  }

  void playerInput(ArrowDirection playerAction) {
    if (!mounted ||
        state.gameEnded ||
        !state.awaitingInput ||
        state.commandQueue.isEmpty) {
      return;
    }
    _handlePlayerInput(playerAction);
  }

  void _handlePlayerInput(ArrowDirection? playerAction) {
    if (!mounted || state.gameEnded) {
      return;
    }

    state = state.copyWith(
        playerActionFeedback: playerAction, awaitingInput: false);

    bool isCorrect;
    ArrowDirection expectedDirection = state.commandQueue.first;

    if (state.currentMode == GameMode.normal) {
      isCorrect = (playerAction == expectedDirection);
    } else {
      switch (expectedDirection) {
        case ArrowDirection.up:
          isCorrect = (playerAction == ArrowDirection.down);
          break;
        case ArrowDirection.down:
          isCorrect = (playerAction == ArrowDirection.up);
          break;
        case ArrowDirection.left:
          isCorrect = (playerAction == ArrowDirection.right);
          break;
        case ArrowDirection.right:
          isCorrect = (playerAction == ArrowDirection.left);
          break;
      }
    }

    if (isCorrect) {
      final newCombo = state.combo + 1;
      final pointsEarnedThisTurn = newCombo;
      final newScore = state.score + pointsEarnedThisTurn;

      final newTimeLeft = (state.timeLeft + faTimeBonusPerCorrect)
          .clamp(0.0, faMaxTimeLimitSeconds);
      final newCorrectAnswersCount = state.correctAnswersCount + 1;

      if (kDebugMode) {
        print(
            "Correct! Correct Answers: $newCorrectAnswersCount, Combo: $newCombo, Points: $pointsEarnedThisTurn, Score: $newScore, Time: $newTimeLeft");
      }
      if (mounted) {
        state = state.copyWith(
          lastAnswerCorrect: true,
          score: newScore,
          combo: newCombo,
          timeLeft: newTimeLeft,
          correctAnswersCount: newCorrectAnswersCount,
        );
      }
      _checkModeToggle();
      _updateCommandQueue();
    } else {
      final newTimeLeft = (state.timeLeft - faTimePenaltyPerWrong)
          .clamp(0.0, faMaxTimeLimitSeconds);
      if (kDebugMode) {
        print("Wrong! Combo reset. Time left: $newTimeLeft");
      }

      if (!mounted) return;
      state = state.copyWith(
        lastAnswerCorrect: false,
        timeLeft: newTimeLeft,
        combo: 0,
      );

      if (newTimeLeft <= 0 && !state.gameEnded) {
        _endGame(reason: "시간 초과! (오답 페널티)", userGaveUp: false);
        return;
      }

      Future.delayed(faIncorrectFeedbackDuration, () {
        if (!mounted || state.gameEnded) {
          return;
        }
        _updateCommandQueue();
      });
    }
  }

  void _checkModeToggle() {
    if (!mounted || state.gameEnded) {
      return;
    }
    if (state.correctAnswersCount >= _nextModeToggleCount) {
      GameMode newMode = state.currentMode == GameMode.normal
          ? GameMode.reverse
          : GameMode.normal;
      String overlayText = newMode == GameMode.reverse ? "반대 모드!" : "일반 모드!";
      _modeChangeCount++;

      if (kDebugMode) {
        print(
            "Mode Toggle! New mode: $newMode, Correct Answers: ${state.correctAnswersCount}");
      }

      if (mounted) {
        state = state.copyWith(
          currentMode: newMode,
          modeChangeOverlayText: overlayText,
          currentModeBonusPoints: (_modeChangeCount * 2),
        );
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          state = state.copyWith(clearModeChangeOverlay: true);
        }
      });

      _nextModeToggleCount =
          state.correctAnswersCount + _generateWeightedRandomInterval();
      if (kDebugMode) {
        print("Next mode toggle count set to: $_nextModeToggleCount");
      }
    }
  }

  void giveUpGame() {
    if (!mounted || state.gameEnded) {
      return;
    }
    _endGame(reason: "게임 포기", userGaveUp: true);
  }

  void _endGame({required String reason, required bool userGaveUp}) async {
    if (state.gameEnded && !userGaveUp) return;

    _gameTimer?.cancel();

    if (!userGaveUp) {
      _ref.read(adHelperProvider).handleGameEnd();
    }

    final int sessionScore = state.score;

    state = state.copyWith(
      gameEnded: true,
      gameEndReason: reason,
      timeLeft: 0,
      awaitingInput: false,
    );

    if (kDebugMode) {
      print("FollowArrowsGame Ended: $reason, Final Score: $sessionScore");
    }

    if (userGaveUp || sessionScore <= 0) return;

    final UserModel? currentUser = _ref.read(userProfileProvider).asData?.value;
    final AuthService authService = _ref.read(authServiceProvider);

    if (currentUser != null && currentUser.schoolId.isNotEmpty) {
      try {
        await authService.recordGameResult(
          userId: currentUser.uid,
          gameId: "follow_arrows_game",
          pointsEarnedInSession: sessionScore,
          schoolId: currentUser.schoolId,
        );
        if (kDebugMode) {
          print("Score $sessionScore for follow_arrows_game saved.");
        }

        if (mounted) {
          _ref.invalidate(userProfileProvider);
        }
      } catch (e) {
        if (kDebugMode) {
          print("Failed to save follow_arrows_game score: $e");
        }
        if (mounted) {
          state = state.copyWith(gameEndReason: "점수 저장 실패 ($reason)");
        }
      }
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}

final followArrowsGameStateProvider = StateNotifierProvider.autoDispose<
    FollowArrowsGameStateNotifier, FollowArrowsGameState>(
  (ref) => FollowArrowsGameStateNotifier(ref),
);
