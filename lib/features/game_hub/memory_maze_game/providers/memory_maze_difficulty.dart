// lib/features/game_hub/memory_maze_game/providers/memory_maze_difficulty.dart
import 'dart:math';

/// 난이도/시간/밀집도(빈칸 비율) 설정을 한 곳에서 관리
class MemoryMazeDifficulty {
  // 빈칸 비율(= 길 비율). N이 커질수록 약간 줄이고, 라운드가 올라갈수록도 미세히 줄임.
  final double openRatioBase; // 기본 빈칸 비율
  final double openRatioSizeCoef; // 보드 크기별 보정
  final double openRatioRoundCoef; // 라운드별 보정
  final double openRatioMin;
  final double openRatioMax;

  // 해답(최단 경로) 최소 길이
  final double minLenCoef; // N*N에 대한 비율
  final int minLenFloor; // 최저 보장

  // 시간 스케일링
  final double memoryTimeBase;
  final double memoryTimePerCell;
  final double playTimeBase;
  final double playTimePerCell;
  final double playTimeRoundCoef;

  const MemoryMazeDifficulty({
    this.openRatioBase = 0.55,
    this.openRatioSizeCoef = 0.02,
    this.openRatioRoundCoef = 0.005,
    this.openRatioMin = 0.38,
    this.openRatioMax = 0.65,
    this.minLenCoef = 0.35,
    this.minLenFloor = 4,
    this.memoryTimeBase = 2.0,
    this.memoryTimePerCell = 0.35,
    this.playTimeBase = 7.0,
    this.playTimePerCell = 0.9,
    this.playTimeRoundCoef = 0.3,
  });

  // ✅ 라운드별 보드 크기 N을 직접 반환 (3→10까지)
  int boardSizeForRound(int round) {
    if (round == 1) return 3; // 1: 3x3
    if (round <= 3) return 4; // 2-3: 4x4
    if (round <= 5) return 5; // 4-5: 5x5
    if (round <= 7) return 6; // 6-7: 6x6
    if (round <= 9) return 7; // 8-9: 7x7
    if (round <= 11) return 8; // 10-11: 8x8
    if (round <= 13) return 9; // 12-13: 9x9
    return 10; // 14+: 10x10
  }

  // 라운드/보드크기에 따른 빈칸 비율(길 비율)
  double openRatio(int boardSize, int round) => (openRatioBase -
          boardSize * openRatioSizeCoef -
          round * openRatioRoundCoef)
      .clamp(openRatioMin, openRatioMax);

  // 최단경로 최소 길이
  int minSolutionLen(int boardSize, int round) =>
      max(minLenFloor, (boardSize * boardSize * minLenCoef).round());

  // 시간 계산
  double memoryTimeSec(int boardSize, int round) =>
      max(memoryTimeBase, boardSize * boardSize * memoryTimePerCell);

  double playTimeSec(int boardSize, int round) => max(
      playTimeBase, boardSize * playTimePerCell - round * playTimeRoundCoef);
}

const kDefaultMemoryMazeDifficulty = MemoryMazeDifficulty();
