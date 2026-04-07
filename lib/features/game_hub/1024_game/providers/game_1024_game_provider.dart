// lib/features/game_hub/1024_game/providers/game_1024_game_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ranking_ground_v1/core/ads/ad_helper.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/1024_game/models/game_1024_model.dart';

final game1024Provider =
    StateNotifierProvider.autoDispose<Game1024Notifier, GameState>((ref) {
  return Game1024Notifier(ref);
});

class Game1024Notifier extends StateNotifier<GameState> {
  Timer? _timer;
  final Ref _ref;
  // ⭐️ [수정] 게임 종료 로직의 중복 실행을 막기 위한 변수 추가
  bool _isGameEnding = false;

  Game1024Notifier(this._ref) : super(GameState.initial()) {
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || state.gameStatus != GameStatus1024.playing) {
        timer.cancel();
        return;
      }
      if (state.remainingTime > 0) {
        final newTime = state.remainingTime - 0.1;
        if (newTime < 0) {
          state = state.copyWith(remainingTime: 0);
        } else {
          state = state.copyWith(remainingTime: newTime);
        }
      } else {
        _endGame(userGaveUp: false);
      }
    });
  }

  void startNewGame() {
    // ⭐️ [수정] 새 게임 시작 시 종료 상태 변수 초기화
    _isGameEnding = false;
    state = GameState.initial();
    _startTimer();
  }

  void _endGame({required bool userGaveUp}) async {
    // ⭐️ [수정] 기존 방어 코드를 새로운 방식으로 변경
    if (_isGameEnding && !userGaveUp) return;
    _isGameEnding = true;

    _timer?.cancel();

    if (state.gameStatus == GameStatus1024.playing) {
      state =
          state.copyWith(gameStatus: GameStatus1024.gameOver, remainingTime: 0);
    }

    if (!userGaveUp) {
      _ref.read(adHelperProvider).handleGameEnd();
    }

    final sessionScore = state.score;
    final currentUser = _ref.read(userProfileProvider).asData?.value;
    if (currentUser == null ||
        currentUser.schoolId.isEmpty ||
        sessionScore <= 0) {
      return;
    }

    try {
      await _ref.read(authServiceProvider).recordGameResult(
            userId: currentUser.uid,
            gameId: 'game_1024',
            pointsEarnedInSession: sessionScore,
            schoolId: currentUser.schoolId,
          );
      if (kDebugMode) print("Score $sessionScore for game_1024 saved.");
      _ref.invalidate(userProfileProvider);
    } catch (e) {
      if (kDebugMode) print("Failed to save game_1024 score: $e");
    }
  }

  void giveUpAndEndGame() {
    _endGame(userGaveUp: true);
  }

  void move(SwipeDirection direction) {
    if (state.gameStatus != GameStatus1024.playing) return;

    final moveResult = state.moveTiles(direction);
    if (moveResult.moved) {
      final newTime = state.remainingTime + moveResult.timeGained;
      state = moveResult.gameState.copyWith(
        score: state.score + moveResult.scoreGained,
        remainingTime: newTime,
      );
    }

    if (state.gameStatus != GameStatus1024.playing) {
      _endGame(userGaveUp: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
