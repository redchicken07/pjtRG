// lib/features/ranking/providers/ranking_school_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ranking_ground_v1/data/models/school_model.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';

final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);

// --- 홈 화면용 Top5: 배치 집계된 overallRank 기준 ---
final topSchoolRankingProvider =
    StreamProvider.autoDispose<List<SchoolModel>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('schools')
      .where('overallRank', isGreaterThan: 0)
      .orderBy('overallRank')
      .limit(5)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => SchoolModel.fromFirestore(doc)).toList());
});

final userSchoolProvider = StreamProvider.autoDispose<SchoolModel?>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final userProfile = ref.watch(userProfileProvider).asData?.value;
  if (userProfile?.schoolId == null || userProfile!.schoolId.isEmpty) {
    return Stream.value(null);
  }
  return firestore
      .collection('schools')
      .doc(userProfile.schoolId)
      .snapshots()
      .map((snapshot) =>
          snapshot.exists ? SchoolModel.fromFirestore(snapshot) : null);
});

// --- "학교 랭킹" 탭 화면용 ---
const schoolRankingPageLimit = 20;

// 1. 전국 학교 랭킹 Provider
final schoolRankingNotifierProvider =
    AsyncNotifierProvider.autoDispose<SchoolRankingNotifier, List<SchoolModel>>(
        SchoolRankingNotifier.new);

class SchoolRankingNotifier
    extends AutoDisposeAsyncNotifier<List<SchoolModel>> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;

  @override
  Future<List<SchoolModel>> build() async {
    _lastDocument = null;
    _hasMore = true;
    return _fetchPage();
  }

  Future<List<SchoolModel>> _fetchPage() async {
    if (!_hasMore) return state.valueOrNull ?? [];

    Query query = ref
        .read(firestoreProvider)
        .collection('schools')
        .orderBy('score_total', descending: true)
        .orderBy(FieldPath.documentId);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }
    final snapshot = await query.limit(schoolRankingPageLimit).get();
    if (snapshot.docs.length < schoolRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;

    return snapshot.docs.map((doc) => SchoolModel.fromFirestore(doc)).toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<SchoolModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage()]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

// --- ⭐️ 새로 추가된 부분: 지역별 학교 랭킹 Provider ⭐️ ---
final citySchoolRankingProvider = AsyncNotifierProvider.autoDispose
    .family<CitySchoolRankingNotifier, List<SchoolModel>, String>(
        CitySchoolRankingNotifier.new);

class CitySchoolRankingNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<SchoolModel>, String> {
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool get hasMoreData => _hasMore;

  @override
  Future<List<SchoolModel>> build(String city) async {
    _lastDocument = null;
    _hasMore = true;
    return _fetchPage(city);
  }

  Future<List<SchoolModel>> _fetchPage(String city) async {
    if (!_hasMore) return state.valueOrNull ?? [];

    Query query = ref
        .read(firestoreProvider)
        .collection('schools')
        .where('city', isEqualTo: city)
        .orderBy('score_total', descending: true)
        .orderBy(FieldPath.documentId);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }
    final snapshot = await query.limit(schoolRankingPageLimit).get();
    if (snapshot.docs.length < schoolRankingPageLimit) _hasMore = false;
    if (snapshot.docs.isNotEmpty) _lastDocument = snapshot.docs.last;

    return snapshot.docs.map((doc) => SchoolModel.fromFirestore(doc)).toList();
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isRefreshing || !_hasMore) return;
    state = AsyncLoading<List<SchoolModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
        () async => [...state.valueOrNull ?? [], ...await _fetchPage(arg)]);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}
