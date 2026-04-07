// lib/features/game_hub/1024_game/models/game_1024_model.dart

import 'dart:math';
import 'package:ranking_ground_v1/features/game_hub/1024_game/models/game_1024_constants.dart';

class MoveResult {
  final GameState gameState;
  final int scoreGained;
  final double timeGained;
  final bool moved;

  MoveResult({
    required this.gameState,
    this.scoreGained = 0,
    this.timeGained = 0,
    this.moved = false,
  });
}

enum SwipeDirection { up, down, left, right }

enum TileMergeStatus { none, merged }

// --- ⭐️ 수정된 부분: id 필드 추가 ---
class TileModel {
  final int value;
  final int id; // 타일의 고유 ID (애니메이션 구분을 위함)
  final TileMergeStatus status;

  TileModel({
    required this.value,
    required this.id,
    this.status = TileMergeStatus.none,
  });

  TileModel copyWith({int? value, int? id, TileMergeStatus? status}) {
    return TileModel(
      value: value ?? this.value,
      id: id ?? this.id,
      status: status ?? this.status,
    );
  }
}

enum GameStatus1024 { playing, won, gameOver }

class GameState {
  final List<List<TileModel?>> grid;
  final int score;
  final double remainingTime;
  final int highestTileValue;
  final GameStatus1024 gameStatus;

  // --- ⭐️ 수정된 부분: 타일 ID를 위한 고유 카운터 추가 ---
  final int _tileIdCounter;

  GameState({
    required this.grid,
    required this.score,
    required this.remainingTime,
    required this.highestTileValue,
    required this.gameStatus,
    int tileIdCounter = 0,
  }) : _tileIdCounter = tileIdCounter;

  factory GameState.initial() {
    final size = GameConstants1024.gridSize;
    final grid = List.generate(size, (_) => List.generate(size, (_) => null));

    var state = GameState(
      grid: grid,
      score: 0,
      remainingTime: GameConstants1024.initialTime,
      highestTileValue: 0,
      gameStatus: GameStatus1024.playing,
    );
    state = state._addRandomTile();
    state = state._addRandomTile();
    return state;
  }

  GameState copyWith(
      {List<List<TileModel?>>? grid,
      int? score,
      double? remainingTime,
      int? highestTileValue,
      GameStatus1024? gameStatus,
      int? tileIdCounter}) {
    return GameState(
      grid: grid ?? this.grid.map((row) => List<TileModel?>.from(row)).toList(),
      score: score ?? this.score,
      remainingTime: remainingTime ?? this.remainingTime,
      highestTileValue: highestTileValue ?? this.highestTileValue,
      gameStatus: gameStatus ?? this.gameStatus,
      tileIdCounter: tileIdCounter ?? _tileIdCounter,
    );
  }

  GameState _addRandomTile() {
    final size = GameConstants1024.gridSize;
    final emptyPositions = <Point<int>>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] == null) emptyPositions.add(Point(r, c));
      }
    }
    if (emptyPositions.isEmpty) return this;

    final random = Random();
    final pos = emptyPositions[random.nextInt(emptyPositions.length)];
    final newValue = (random.nextInt(10) < 9) ? 2 : 4;

    final newGrid = grid
        .map((row) => row.map((tile) => tile?.copyWith()).toList())
        .toList();

    // --- ⭐️ 수정된 부분: 새로운 타일에 고유 ID 부여 ---
    final newTileId = _tileIdCounter + 1;
    newGrid[pos.x][pos.y] = TileModel(value: newValue, id: newTileId);
    return copyWith(grid: newGrid, tileIdCounter: newTileId);
  }

  MoveResult moveTiles(SwipeDirection direction) {
    if (gameStatus != GameStatus1024.playing) {
      return MoveResult(gameState: this, moved: false);
    }

    final size = GameConstants1024.gridSize;
    List<List<TileModel?>> newGrid =
        List.generate(size, (_) => List.generate(size, (_) => null));
    int scoreThisMove = 0;
    double timeBonusThisMove = 0;
    int currentHighest = highestTileValue;
    bool moved = false;
    int nextTileId = _tileIdCounter;

    ({List<TileModel?> line, int score, double time}) processLine(
        List<TileModel?> line) {
      final inputTiles =
          line.where((t) => t != null).cast<TileModel>().toList();
      final mergedTiles = <TileModel>[];
      int scoreGained = 0;
      double timeGained = 0;
      int idx = 0;

      while (idx < inputTiles.length) {
        if (idx < inputTiles.length - 1 &&
            inputTiles[idx].value == inputTiles[idx + 1].value) {
          final mergedValue = inputTiles[idx].value * 2;

          // --- ⭐️ 수정된 부분: 합쳐진 타일에 새로운 ID 부여 ---
          nextTileId++;
          mergedTiles.add(TileModel(
              value: mergedValue,
              id: nextTileId,
              status: TileMergeStatus.merged));

          scoreGained += mergedValue ~/ 2;
          if (mergedValue >= GameConstants1024.timeBonusThreshold) {
            timeGained += GameConstants1024.timeBonusAmount;
          }
          currentHighest = max(currentHighest, mergedValue);
          idx += 2;
        } else {
          // 이동만 하는 타일은 기존 객체 그대로 사용하여 ID 유지
          mergedTiles.add(inputTiles[idx]);
          idx += 1;
        }
      }
      final outputLine = <TileModel?>[...mergedTiles];
      while (outputLine.length < size) {
        outputLine.add(null);
      }
      return (line: outputLine, score: scoreGained, time: timeGained);
    }

    // (이하 for문과 switch문은 보내주신 원본 코드와 동일)
    for (int i = 0; i < size; i++) {
      List<TileModel?> originalLine;
      switch (direction) {
        case SwipeDirection.left:
          originalLine = grid[i];
          final result = processLine(originalLine);
          newGrid[i] = result.line;
          scoreThisMove += result.score;
          timeBonusThisMove += result.time;
          break;
        case SwipeDirection.right:
          originalLine = grid[i].reversed.toList();
          final result = processLine(originalLine);
          newGrid[i] = result.line.reversed.toList();
          scoreThisMove += result.score;
          timeBonusThisMove += result.time;
          break;
        case SwipeDirection.up:
          originalLine = [for (int r = 0; r < size; r++) grid[r][i]];
          final result = processLine(originalLine);
          for (int r = 0; r < size; r++) {
            newGrid[r][i] = result.line[r];
          }
          scoreThisMove += result.score;
          timeBonusThisMove += result.time;
          break;
        case SwipeDirection.down:
          originalLine = [for (int r = size - 1; r >= 0; r--) grid[r][i]];
          final result = processLine(originalLine);
          for (int r = 0; r < size; r++) {
            newGrid[size - 1 - r][i] = result.line[r];
          }
          scoreThisMove += result.score;
          timeBonusThisMove += result.time;
          break;
      }
    }

    // ... (이하 모든 로직은 변경 없음)
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c]?.value != newGrid[r][c]?.value) {
          moved = true;
          break;
        }
      }
      if (moved) break;
    }
    if (!moved) return MoveResult(gameState: this, moved: false);

    GameState nextState = copyWith(
        grid: newGrid,
        highestTileValue: currentHighest,
        tileIdCounter: nextTileId);
    nextState = nextState._addRandomTile();

    if (currentHighest >= GameConstants1024.targetTile) {
      return MoveResult(
          gameState: nextState.copyWith(gameStatus: GameStatus1024.won),
          scoreGained: scoreThisMove,
          timeGained: timeBonusThisMove,
          moved: true);
    }

    bool canMove = false;
    for (int r = 0; r < size && !canMove; r++) {
      for (int c = 0; c < size; c++) {
        if (nextState.grid[r][c] == null) {
          canMove = true;
          break;
        }
        final v = nextState.grid[r][c]!.value;
        if ((r < size - 1 && nextState.grid[r + 1][c]?.value == v) ||
            (c < size - 1 && nextState.grid[r][c + 1]?.value == v)) {
          canMove = true;
          break;
        }
      }
    }

    if (!canMove) {
      return MoveResult(
          gameState: nextState.copyWith(gameStatus: GameStatus1024.gameOver),
          scoreGained: scoreThisMove,
          timeGained: timeBonusThisMove,
          moved: true);
    }

    return MoveResult(
        gameState: nextState,
        scoreGained: scoreThisMove,
        timeGained: timeBonusThisMove,
        moved: true);
  }
}
