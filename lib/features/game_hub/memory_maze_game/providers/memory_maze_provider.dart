// lib/features/game_hub/memory_maze_game/providers/memory_maze_provider.dart
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/game_hub/memory_maze_game/providers/memory_maze_difficulty.dart';

const String memoryMazeGameId = 'memory_maze_game';
const Duration timerInterval = Duration(milliseconds: 100);

final _difficulty = kDefaultMemoryMazeDifficulty;

enum TileType { path, wall, start, finish }

enum GamePhase { memorizing, playing, roundSuccess, roundFail, gameOver }

class MazePoint extends Point<int> {
  const MazePoint(super.x, super.y);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MazePoint && x == other.x && y == other.y;
  @override
  int get hashCode => Object.hash(x, y);
}

/// 단순 NxN 랜덤 격자 + BFS 경로 보장
class _Grid {
  final int n; // N x N
  final Random random;
  late List<List<TileType>> data;
  late MazePoint start;
  late MazePoint finish;

  _Grid(this.n, this.random) {
    data = List.generate(n, (_) => List.filled(n, TileType.wall));
  }

  bool _inBounds(MazePoint p) => p.x >= 0 && p.x < n && p.y >= 0 && p.y < n;
  Iterable<MazePoint> _neighbors(MazePoint p) sync* {
    const dirs = [Point(0, -1), Point(0, 1), Point(-1, 0), Point(1, 0)];
    for (final d in dirs) {
      final np = MazePoint(p.x + d.x, p.y + d.y);
      if (_inBounds(np) && data[np.y][np.x] != TileType.wall) yield np;
    }
  }

  void randomizeOpenClosed(double openRatio) {
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        data[y][x] =
            (random.nextDouble() < openRatio) ? TileType.path : TileType.wall;
      }
    }
  }

  MazePoint _randomOpenCell() {
    for (int i = 0; i < 200; i++) {
      final p = MazePoint(random.nextInt(n), random.nextInt(n));
      if (data[p.y][p.x] != TileType.wall) return p;
    }
    // fallback: 첫 번째 오픈셀
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        if (data[y][x] != TileType.wall) return MazePoint(x, y);
      }
    }
    return const MazePoint(0, 0); // 전부 벽이면 호출 측에서 실패로 처리
  }

  /// start에서 모든 도달 가능 칸까지 BFS. 경로 복원용 prev 반환.
  (List<List<int>>, Map<MazePoint, MazePoint>) _bfsAll(MazePoint s) {
    final dist = List.generate(n, (_) => List.filled(n, -1));
    final prev = <MazePoint, MazePoint>{};
    final q = Queue<MazePoint>();
    if (data[s.y][s.x] == TileType.wall) return (dist, prev);
    dist[s.y][s.x] = 0;
    q.add(s);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      for (final nb in _neighbors(cur)) {
        if (dist[nb.y][nb.x] == -1) {
          dist[nb.y][nb.x] = dist[cur.y][cur.x] + 1;
          prev[nb] = cur;
          q.add(nb);
        }
      }
    }
    return (dist, prev);
  }

  List<MazePoint> _reconstructPath(
      MazePoint s, MazePoint t, Map<MazePoint, MazePoint> prev) {
    final path = <MazePoint>[];
    MazePoint? cur = t;
    while (cur != null && cur != s) {
      path.add(cur);
      cur = prev[cur];
    }
    if (cur == s) {
      path.add(s);
      return path.reversed.toList();
    }
    return const []; // 실패
  }

  /// 요구된 생성 순서 구현
  /// - 랜덤 벽/길 → 시작점 → BFS로 최장 도달 칸을 도착점 → 경로 없으면 실패
  bool generate(double openRatio, int minSolutionLen) {
    randomizeOpenClosed(openRatio);

    // 시작점: 오픈셀 무작위
    start = _randomOpenCell();
    if (data[start.y][start.x] == TileType.wall) return false;

    // BFS로 모든 오픈셀 거리 계산 후 가장 먼 칸을 도착점으로
    final (dist, prev) = _bfsAll(start);
    int bestD = -1;
    MazePoint? best;
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        if (dist[y][x] > bestD) {
          bestD = dist[y][x];
          best = MazePoint(x, y);
        }
      }
    }
    if (best == null || bestD < 0) return false; // 도달 불가
    finish = best;

    // 최단경로 길이 검증
    final path = _reconstructPath(start, finish, prev);
    if (path.isEmpty || path.length < minSolutionLen) return false;

    // 마킹
    data[start.y][start.x] = TileType.start;
    data[finish.y][finish.x] = TileType.finish;
    return true;
  }
}

class MemoryMazeState {
  final int round;
  final int score;
  final List<List<TileType>> maze;
  final MazePoint startPosition;
  final MazePoint finishPosition;
  final MazePoint playerPosition;
  final double memoryTimeTotal;
  final double memoryTimeLeft;
  final double playTimeTotal;
  final double playTimeLeft;
  final GamePhase gamePhase;
  final bool wallHitFeedback;

  const MemoryMazeState({
    required this.round,
    required this.score,
    required this.maze,
    required this.startPosition,
    required this.finishPosition,
    required this.playerPosition,
    required this.memoryTimeTotal,
    required this.memoryTimeLeft,
    required this.playTimeTotal,
    required this.playTimeLeft,
    required this.gamePhase,
    this.wallHitFeedback = false,
  });

  MemoryMazeState copyWith({
    int? round,
    int? score,
    List<List<TileType>>? maze,
    MazePoint? startPosition,
    MazePoint? finishPosition,
    MazePoint? playerPosition,
    double? memoryTimeTotal,
    double? memoryTimeLeft,
    double? playTimeTotal,
    double? playTimeLeft,
    GamePhase? gamePhase,
    bool? wallHitFeedback,
  }) {
    return MemoryMazeState(
      round: round ?? this.round,
      score: score ?? this.score,
      maze: maze ?? this.maze,
      startPosition: startPosition ?? this.startPosition,
      finishPosition: finishPosition ?? this.finishPosition,
      playerPosition: playerPosition ?? this.playerPosition,
      memoryTimeTotal: memoryTimeTotal ?? this.memoryTimeTotal,
      memoryTimeLeft: memoryTimeLeft ?? this.memoryTimeLeft,
      playTimeTotal: playTimeTotal ?? this.playTimeTotal,
      playTimeLeft: playTimeLeft ?? this.playTimeLeft,
      gamePhase: gamePhase ?? this.gamePhase,
      wallHitFeedback: wallHitFeedback ?? this.wallHitFeedback,
    );
  }
}

class MemoryMazeNotifier extends StateNotifier<MemoryMazeState> {
  final Ref ref;
  final Random _random = Random();
  Timer? _phaseTimer;
  Timer? _flashTimer;
  DateTime? _timerStartTime;
  bool _isEnding = false;

  MemoryMazeNotifier(this.ref)
      : super(const MemoryMazeState(
          round: 1,
          score: 0,
          maze: [],
          startPosition: MazePoint(0, 0),
          finishPosition: MazePoint(0, 0),
          playerPosition: MazePoint(0, 0),
          memoryTimeTotal: 0,
          memoryTimeLeft: 0,
          playTimeTotal: 0,
          playTimeLeft: 0,
          gamePhase: GamePhase.memorizing,
          wallHitFeedback: false,
        ));

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void startGame() {
    _isEnding = false;
    _startNewRound(1, 0);
  }

  void giveUpAndEndGame() {
    _endGame();
  }

  Future<void> _endGame() async {
    if (_isEnding || state.gamePhase == GamePhase.gameOver) return;
    _isEnding = true;

    _phaseTimer?.cancel();
    _flashTimer?.cancel();

    final sessionScore = state.score;
    state = state.copyWith(gamePhase: GamePhase.gameOver);

    // 중도 포기 여부와 관계없이 획득 점수가 있으면 누적 저장합니다.
    if (sessionScore <= 0) return;

    final currentUser = ref.read(userProfileProvider).asData?.value;
    if (currentUser == null || currentUser.schoolId.isEmpty) return;

    try {
      await ref.read(authServiceProvider).recordGameResult(
            userId: currentUser.uid,
            gameId: memoryMazeGameId,
            pointsEarnedInSession: sessionScore,
            schoolId: currentUser.schoolId,
          );
      if (mounted) {
        ref.invalidate(userProfileProvider);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save $memoryMazeGameId score: $e');
      }
    }
  }

  void nextRound() {
    if (state.gamePhase != GamePhase.roundSuccess) return;
    _startNewRound(state.round + 1, state.score);
  }

  void _startNewRound(int round, int score) {
    _phaseTimer?.cancel();
    _flashTimer?.cancel();

    final boardSize = _difficulty.boardSizeForRound(round);
    final memoryTime = _difficulty.memoryTimeSec(boardSize, round);
    final playTime = _difficulty.playTimeSec(boardSize, round);

    final mazeData = _generateMaze(boardSize, round);

    state = MemoryMazeState(
      round: round,
      score: score,
      maze: mazeData['maze'],
      startPosition: mazeData['start'],
      finishPosition: mazeData['finish'],
      playerPosition: mazeData['start'],
      memoryTimeTotal: memoryTime,
      memoryTimeLeft: memoryTime,
      playTimeTotal: playTime,
      playTimeLeft: playTime,
      gamePhase: GamePhase.memorizing,
      wallHitFeedback: false,
    );

    _startRoundTimer();
  }

  void _startRoundTimer() {
    final memoryTotal = state.memoryTimeTotal;
    final playTotal = state.playTimeTotal;
    final roundTotal = memoryTotal + playTotal;

    _timerStartTime = DateTime.now();
    _phaseTimer = Timer.periodic(timerInterval, (timer) {
      final elapsed =
          DateTime.now().difference(_timerStartTime!).inMilliseconds / 1000.0;
      final totalLeft = (roundTotal - elapsed).clamp(0.0, 999.0);
      if (totalLeft <= 0.0) {
        timer.cancel();
        _onRoundFail();
        return;
      }

      final inMemorizing = elapsed < memoryTotal;
      final memoryLeft =
          inMemorizing ? (memoryTotal - elapsed).clamp(0.0, 999.0) : 0.0;
      final playElapsed = (elapsed - memoryTotal).clamp(0.0, playTotal);
      final playLeft = (playTotal - playElapsed).clamp(0.0, 999.0);

      state = state.copyWith(
        gamePhase: inMemorizing ? GamePhase.memorizing : GamePhase.playing,
        memoryTimeLeft: memoryLeft,
        playTimeLeft: playLeft,
      );
    });
  }

  void _onRoundFail() {
    _phaseTimer?.cancel();
    state = state.copyWith(
      gamePhase: GamePhase.roundFail,
      memoryTimeLeft: 0.0,
      playTimeLeft: 0.0,
    );
  }

  void movePlayer(Point<int> delta) {
    if (state.gamePhase != GamePhase.memorizing &&
        state.gamePhase != GamePhase.playing) {
      return;
    }
    final next = MazePoint(
        state.playerPosition.x + delta.x, state.playerPosition.y + delta.y);
    if (!_isWalkable(next)) {
      _flashWallHit();
      return;
    }
    if (next == state.finishPosition) {
      _phaseTimer?.cancel();
      final n = state.maze.length;
      final base = (state.round * n * 10).ceil();
      final remainingTime = state.memoryTimeLeft + state.playTimeLeft;
      final bonus = (remainingTime * n * state.round).ceil();
      state = state.copyWith(
        playerPosition: next,
        score: state.score + base + bonus,
        gamePhase: GamePhase.roundSuccess,
      );
      return;
    }
    state = state.copyWith(playerPosition: next, wallHitFeedback: false);
  }

  void _flashWallHit() {
    _flashTimer?.cancel();
    state = state.copyWith(wallHitFeedback: true);
    _flashTimer = Timer(const Duration(milliseconds: 150), () {
      state = state.copyWith(wallHitFeedback: false);
    });
  }

  bool _isWalkable(MazePoint p) {
    final n = state.maze.length;
    if (p.y < 0 || p.y >= n || p.x < 0 || p.x >= n) return false;
    return state.maze[p.y][p.x] != TileType.wall;
  }

  Map<String, dynamic> _generateMaze(int boardSize, int round) {
    final openRatio = _difficulty.openRatio(boardSize, round);
    final minLen = _difficulty.minSolutionLen(boardSize, round);
    for (int attempt = 0; attempt < 200; attempt++) {
      final grid = _Grid(boardSize, _random);
      final ok = grid.generate(openRatio, minLen);
      if (ok) {
        return {
          'maze': grid.data,
          'start': grid.start,
          'finish': grid.finish,
        };
      }
    }
    // 매우 드물게 실패하면, 전부 길로 열어서라도 진행
    final fallback = _Grid(boardSize, _random)..randomizeOpenClosed(1.0);
    fallback.start = const MazePoint(0, 0);
    fallback.finish = MazePoint(boardSize - 1, boardSize - 1);
    fallback.data[fallback.start.y][fallback.start.x] = TileType.start;
    fallback.data[fallback.finish.y][fallback.finish.x] = TileType.finish;
    return {
      'maze': fallback.data,
      'start': fallback.start,
      'finish': fallback.finish,
    };
  }
}

final memoryMazeProvider =
    StateNotifierProvider.autoDispose<MemoryMazeNotifier, MemoryMazeState>(
  (ref) => MemoryMazeNotifier(ref),
);
