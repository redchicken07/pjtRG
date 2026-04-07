// lib/features/ranking/providers/ranking_personal_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ranking_ground_v1/data/models/user_model.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'ranking_school_provider.dart';

// --- 홈 화면용 Top5 개인 랭킹: 배치 집계된 overallRank 기준
final topPersonalRankingProvider =
    StreamProvider.autoDispose<List<UserModel>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .where('overallRank', isGreaterThan: 0)
      .orderBy('overallRank')
      .limit(5)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList());
});

// --- 홈 화면용 학교 내부 Top10: 배치 집계된 schoolRank 기준
final schoolInternalTopRankingProvider =
    StreamProvider.autoDispose<List<UserModel>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final userProfile = ref.watch(userProfileProvider).asData?.value;
  if (userProfile?.schoolId == null || userProfile!.schoolId.isEmpty) {
    return Stream.value([]);
  }
  return firestore
      .collection('users')
      .where('schoolId', isEqualTo: userProfile.schoolId)
      .orderBy('schoolRank')
      .limit(10)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList());
});

// --- "개인 랭킹" 탭 화면용 ---
final availableRankingTypesProvider =
    Provider<List<Map<String, String>>>((ref) {
  return [
    {'id': 'overall_score', 'name': '통합 점수'},
    {'id': 'memory_maze_game', 'name': '메모리 미로'},
    {'id': 'follow_arrows_game', 'name': '화살표 따라가기'},
    {'id': 'game_1024', 'name': '1024 퍼즐 게임'},
  ];
});

enum GameScoreMode { best, total }

final selectedRankingTypeProvider =
    StateProvider<String>((ref) => 'overall_score');
final selectedGameScoreModeProvider =
    StateProvider<GameScoreMode>((ref) => GameScoreMode.total);

const personalRankingPageLimit = 20;
typedef GameSchoolArgs = ({String gameId, String schoolId});

// 1-1. 전국 - 통합 최고점수
final bestOverallRankingProvider = AsyncNotifierProvider.autoDispose<
    BestOverallRankingNotifier,
    List<UserModel>>(BestOverallRankingNotifier.new);

class BestOverallRankingNotifier
    extends AutoDisposeAsyncNotifier<List<UserModel>> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;
  @override
  Future<List<UserModel>> build() async {
    _lastDocument = null;
    _hasMore = true;
    return _fetchPage();
  }

  Future<List<UserModel>> _fetchPage() async {
    if (!_hasMore) return state.valueOrNull ?? [];
    Query query = ref
        .read(firestoreProvider)
        .collection('users')
        .orderBy('score_best_personal', descending: true)
        .orderBy(FieldPath.documentId);
    if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);
    final snapshot = await query.limit(personalRankingPageLimit).get();
    if (snapshot.docs.length < personalRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;
    return snapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<UserModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage()]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

// 1-2. 전국 - 통합 누적점수
final totalOverallRankingProvider = AsyncNotifierProvider.autoDispose<
    TotalOverallRankingNotifier,
    List<UserModel>>(TotalOverallRankingNotifier.new);

class TotalOverallRankingNotifier
    extends AutoDisposeAsyncNotifier<List<UserModel>> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;
  @override
  Future<List<UserModel>> build() async {
    _lastDocument = null;
    _hasMore = true;
    return _fetchPage();
  }

  Future<List<UserModel>> _fetchPage() async {
    if (!_hasMore) return state.valueOrNull ?? [];
    Query query = ref
        .read(firestoreProvider)
        .collection('users')
        .orderBy('score_total_personal', descending: true)
        .orderBy(FieldPath.documentId);
    if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);
    final snapshot = await query.limit(personalRankingPageLimit).get();
    if (snapshot.docs.length < personalRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;
    return snapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<UserModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage()]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

// 2. 전국 - 게임별 최고 점수
final bestScoreNationwideRankingProvider = AsyncNotifierProvider.autoDispose
    .family<BestScoreNationwideRankingNotifier, List<UserModel>, String>(
        BestScoreNationwideRankingNotifier.new);

class BestScoreNationwideRankingNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<UserModel>, String> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;
  @override
  Future<List<UserModel>> build(String gameId) async {
    _lastDocument = null;
    _hasMore = true;
    return await _fetchPage(gameId);
  }

  Future<List<UserModel>> _fetchPage(String gameId) async {
    if (!_hasMore) return state.valueOrNull ?? [];
    Query query = ref
        .read(firestoreProvider)
        .collection('users')
        .orderBy('best_scores_by_game.$gameId', descending: true)
        .orderBy(FieldPath.documentId);
    if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);
    final snapshot = await query.limit(personalRankingPageLimit).get();
    if (snapshot.docs.length < personalRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;
    return snapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<UserModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage(arg)]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

// 3. 전국 - 게임별 누적 점수
final totalScoreNationwideRankingProvider = AsyncNotifierProvider.autoDispose
    .family<TotalScoreNationwideRankingNotifier, List<UserModel>, String>(
        TotalScoreNationwideRankingNotifier.new);

class TotalScoreNationwideRankingNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<UserModel>, String> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;
  @override
  Future<List<UserModel>> build(String gameId) async {
    _lastDocument = null;
    _hasMore = true;
    return await _fetchPage(gameId);
  }

  Future<List<UserModel>> _fetchPage(String gameId) async {
    if (!_hasMore) return state.valueOrNull ?? [];
    Query query = ref
        .read(firestoreProvider)
        .collection('users')
        .orderBy('total_scores_by_game.$gameId', descending: true)
        .orderBy(FieldPath.documentId);
    if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);
    final snapshot = await query.limit(personalRankingPageLimit).get();
    if (snapshot.docs.length < personalRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;
    return snapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<UserModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage(arg)]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

// 4-1. 학교 내 - 통합 최고점수
final schoolBestOverallRankingProvider = AsyncNotifierProvider.autoDispose
    .family<SchoolBestOverallRankingNotifier, List<UserModel>, String>(
        SchoolBestOverallRankingNotifier.new);

class SchoolBestOverallRankingNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<UserModel>, String> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;
  @override
  Future<List<UserModel>> build(String schoolId) async {
    _lastDocument = null;
    _hasMore = true;
    return _fetchPage(schoolId);
  }

  Future<List<UserModel>> _fetchPage(String schoolId) async {
    if (!_hasMore) return state.valueOrNull ?? [];
    Query query = ref
        .read(firestoreProvider)
        .collection('users')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('score_best_personal', descending: true)
        .orderBy(FieldPath.documentId);
    if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);
    final snapshot = await query.limit(personalRankingPageLimit).get();
    if (snapshot.docs.length < personalRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;
    return snapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<UserModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage(arg)]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

// 4-2. 학교 내 - 통합 누적점수
final schoolTotalOverallRankingProvider = AsyncNotifierProvider.autoDispose
    .family<SchoolTotalOverallRankingNotifier, List<UserModel>, String>(
        SchoolTotalOverallRankingNotifier.new);

class SchoolTotalOverallRankingNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<UserModel>, String> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;
  @override
  Future<List<UserModel>> build(String schoolId) async {
    _lastDocument = null;
    _hasMore = true;
    return _fetchPage(schoolId);
  }

  Future<List<UserModel>> _fetchPage(String schoolId) async {
    if (!_hasMore) return state.valueOrNull ?? [];
    Query query = ref
        .read(firestoreProvider)
        .collection('users')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('score_total_personal', descending: true)
        .orderBy(FieldPath.documentId);
    if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);
    final snapshot = await query.limit(personalRankingPageLimit).get();
    if (snapshot.docs.length < personalRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;
    return snapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<UserModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage(arg)]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

// 5. 학교 내 - 게임별 최고 점수
final bestScoreSchoolRankingProvider = AsyncNotifierProvider.autoDispose
    .family<BestScoreSchoolRankingNotifier, List<UserModel>, GameSchoolArgs>(
        BestScoreSchoolRankingNotifier.new);

class BestScoreSchoolRankingNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<UserModel>, GameSchoolArgs> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;
  @override
  Future<List<UserModel>> build(GameSchoolArgs args) async {
    _lastDocument = null;
    _hasMore = true;
    return _fetchPage(args);
  }

  Future<List<UserModel>> _fetchPage(GameSchoolArgs args) async {
    if (!_hasMore) return state.valueOrNull ?? [];
    Query query = ref
        .read(firestoreProvider)
        .collection('users')
        .where('schoolId', isEqualTo: args.schoolId)
        .orderBy('best_scores_by_game.${args.gameId}', descending: true)
        .orderBy(FieldPath.documentId);
    if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);
    final snapshot = await query.limit(personalRankingPageLimit).get();
    if (snapshot.docs.length < personalRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;
    return snapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<UserModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage(arg)]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

// 6. 학교 내 - 게임별 누적 점수
final totalScoreSchoolRankingProvider = AsyncNotifierProvider.autoDispose
    .family<TotalScoreSchoolRankingNotifier, List<UserModel>, GameSchoolArgs>(
        TotalScoreSchoolRankingNotifier.new);

class TotalScoreSchoolRankingNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<UserModel>, GameSchoolArgs> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;
  @override
  Future<List<UserModel>> build(GameSchoolArgs args) async {
    _lastDocument = null;
    _hasMore = true;
    return _fetchPage(args);
  }

  Future<List<UserModel>> _fetchPage(GameSchoolArgs args) async {
    if (!_hasMore) return state.valueOrNull ?? [];
    Query query = ref
        .read(firestoreProvider)
        .collection('users')
        .where('schoolId', isEqualTo: args.schoolId)
        .orderBy('total_scores_by_game.${args.gameId}', descending: true)
        .orderBy(FieldPath.documentId);
    if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);
    final snapshot = await query.limit(personalRankingPageLimit).get();
    if (snapshot.docs.length < personalRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;
    return snapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<UserModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage(arg)]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}
