// lib/features/ranking/screens/personal_ranking_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ranking_ground_v1/data/models/user_model.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/ranking/providers/ranking_personal_provider.dart';
import 'package:intl/intl.dart'; // 숫자 포맷팅을 위해 import

class PersonalRankingScreen extends ConsumerStatefulWidget {
  const PersonalRankingScreen({super.key});

  @override
  ConsumerState<PersonalRankingScreen> createState() =>
      _PersonalRankingScreenState();
}

class _PersonalRankingScreenState extends ConsumerState<PersonalRankingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myProfile = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '전국 랭킹'),
            Tab(text: '우리 학교 랭킹'),
          ],
        ),
      ),
      // ⭐️ [수정 1] : body를 Stack으로 감싸 배경과 콘텐츠를 겹치도록 변경
      body: Stack(
        children: [
          // ⭐️ [수정 2] : 배경 이미지 추가 (학교 랭킹 화면과 동일한 방식)
          Positioned.fill(
            child: Opacity(
              opacity: 0.9, // 투명도 조절
              child: Image.asset(
                'assets/background_ranking_personal.png', // ❗️사전 준비에서 추가한 이미지 경로
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.grey.shade200),
              ),
            ),
          ),

          // 기존 TabBarView 콘텐츠
          TabBarView(
            controller: _tabController,
            children: [
              _RankingView(isSchoolRanking: false),
              if (myProfile?.schoolId != null && myProfile!.schoolId.isNotEmpty)
                _RankingView(
                    isSchoolRanking: true, schoolId: myProfile.schoolId)
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('소속된 학교가 없습니다.\nMy Page에서 학교를 설정해주세요.',
                        textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankingView extends ConsumerWidget {
  final bool isSchoolRanking;
  final String? schoolId;

  const _RankingView({required this.isSchoolRanking, this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingTypes = ref.watch(availableRankingTypesProvider);
    final selectedType = ref.watch(selectedRankingTypeProvider);
    final selectedMode = ref.watch(selectedGameScoreModeProvider);

    if (isSchoolRanking && (schoolId == null || schoolId!.isEmpty)) {
      return const Center(child: Text("학교 정보가 없습니다."));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<String>(
            key: ValueKey('ranking-type-$selectedType'),
            initialValue: selectedType,
            items: rankingTypes.map((game) {
              return DropdownMenuItem<String>(
                value: game['id'] as String,
                child: Text(game['name']!),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(selectedRankingTypeProvider.notifier).state = value;
              }
            },
            decoration: InputDecoration(
              filled: true, // ⭐️ 배경색 채우기 추가
              fillColor: Colors.white.withAlpha(190), // ⭐️ 반투명 배경색
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none), // ⭐️ 테두리 제거
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SegmentedButton<GameScoreMode>(
            style: SegmentedButton.styleFrom(
              // ⭐️ 버튼 스타일 추가
              backgroundColor: Colors.white.withAlpha(70),
              foregroundColor: Colors.black87,
              selectedBackgroundColor:
                  Theme.of(context).colorScheme.primary.withAlpha(200),
              selectedForegroundColor: Colors.white,
            ),
            segments: [
              ButtonSegment(
                  value: GameScoreMode.best,
                  label: Text(
                      selectedType == 'overall_score' ? '최고점수 합산' : '최고 점수')),
              ButtonSegment(
                  value: GameScoreMode.total,
                  label: Text(
                      selectedType == 'overall_score' ? '누적점수 합산' : '누적 점수')),
            ],
            selected: {selectedMode},
            onSelectionChanged: (newSelection) {
              ref.read(selectedGameScoreModeProvider.notifier).state =
                  newSelection.first;
            },
          ),
        ),
        Expanded(
          child: _RankingList(
            key: ValueKey(
                '$isSchoolRanking-$schoolId-$selectedType-$selectedMode'),
            isSchoolRanking: isSchoolRanking,
            schoolId: schoolId,
            selectedType: selectedType,
            selectedMode: selectedMode,
          ),
        ),
      ],
    );
  }
}

class _RankingList extends ConsumerStatefulWidget {
  final bool isSchoolRanking;
  final String? schoolId;
  final String selectedType;
  final GameScoreMode selectedMode;

  const _RankingList({
    super.key,
    required this.isSchoolRanking,
    this.schoolId,
    required this.selectedType,
    required this.selectedMode,
  });

  @override
  ConsumerState<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends ConsumerState<_RankingList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }

    final type = widget.selectedType;
    final mode = widget.selectedMode;
    final isSchool = widget.isSchoolRanking;
    final schoolId = widget.schoolId;

    if (type == 'overall_score') {
      if (mode == GameScoreMode.best) {
        if (isSchool) {
          ref
              .read(schoolBestOverallRankingProvider(schoolId!).notifier)
              .fetchNextPage();
        } else {
          ref.read(bestOverallRankingProvider.notifier).fetchNextPage();
        }
      } else {
        if (isSchool) {
          ref
              .read(schoolTotalOverallRankingProvider(schoolId!).notifier)
              .fetchNextPage();
        } else {
          ref.read(totalOverallRankingProvider.notifier).fetchNextPage();
        }
      }
    } else {
      if (mode == GameScoreMode.best) {
        if (isSchool) {
          ref
              .read(bestScoreSchoolRankingProvider(
                  (gameId: type, schoolId: schoolId!)).notifier)
              .fetchNextPage();
        } else {
          ref
              .read(bestScoreNationwideRankingProvider(type).notifier)
              .fetchNextPage();
        }
      } else {
        if (isSchool) {
          ref
              .read(totalScoreSchoolRankingProvider(
                  (gameId: type, schoolId: schoolId!)).notifier)
              .fetchNextPage();
        } else {
          ref
              .read(totalScoreNationwideRankingProvider(type).notifier)
              .fetchNextPage();
        }
      }
    }
  }

  Future<void> _handleRefresh() async {
    final type = widget.selectedType;
    final mode = widget.selectedMode;
    final isSchool = widget.isSchoolRanking;
    final schoolId = widget.schoolId;

    if (type == 'overall_score') {
      if (mode == GameScoreMode.best) {
        isSchool
            ? await ref
                .read(schoolBestOverallRankingProvider(schoolId!).notifier)
                .refresh()
            : await ref.read(bestOverallRankingProvider.notifier).refresh();
      } else {
        isSchool
            ? await ref
                .read(schoolTotalOverallRankingProvider(schoolId!).notifier)
                .refresh()
            : await ref.read(totalOverallRankingProvider.notifier).refresh();
      }
    } else {
      if (mode == GameScoreMode.best) {
        isSchool
            ? await ref
                .read(bestScoreSchoolRankingProvider(
                    (gameId: type, schoolId: schoolId!)).notifier)
                .refresh()
            : await ref
                .read(bestScoreNationwideRankingProvider(type).notifier)
                .refresh();
      } else {
        isSchool
            ? await ref
                .read(totalScoreSchoolRankingProvider(
                    (gameId: type, schoolId: schoolId!)).notifier)
                .refresh()
            : await ref
                .read(totalScoreNationwideRankingProvider(type).notifier)
                .refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(userProfileProvider).value?.uid;

    final type = widget.selectedType;
    final mode = widget.selectedMode;
    final isSchool = widget.isSchoolRanking;
    final schoolId = widget.schoolId;
    final formatter = NumberFormat('#,###');

    final ProviderListenable<AsyncValue<List<UserModel>>> provider;

    if (type == 'overall_score') {
      if (mode == GameScoreMode.best) {
        provider = isSchool
            ? schoolBestOverallRankingProvider(schoolId!)
            : bestOverallRankingProvider;
      } else {
        provider = isSchool
            ? schoolTotalOverallRankingProvider(schoolId!)
            : totalOverallRankingProvider;
      }
    } else {
      if (mode == GameScoreMode.best) {
        provider = isSchool
            ? bestScoreSchoolRankingProvider(
                (gameId: type, schoolId: schoolId!))
            : bestScoreNationwideRankingProvider(type);
      } else {
        provider = isSchool
            ? totalScoreSchoolRankingProvider(
                (gameId: type, schoolId: schoolId!))
            : totalScoreNationwideRankingProvider(type);
      }
    }

    final rankingAsync = ref.watch(provider);

    return rankingAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: const Center(child: Text('랭킹 정보가 없습니다.'))))));
        }

        final bool hasMoreData;
        if (type == 'overall_score') {
          if (mode == GameScoreMode.best) {
            hasMoreData = isSchool
                ? ref
                    .watch(schoolBestOverallRankingProvider(schoolId!).notifier)
                    .hasMoreData
                : ref.watch(bestOverallRankingProvider.notifier).hasMoreData;
          } else {
            hasMoreData = isSchool
                ? ref
                    .watch(
                        schoolTotalOverallRankingProvider(schoolId!).notifier)
                    .hasMoreData
                : ref.watch(totalOverallRankingProvider.notifier).hasMoreData;
          }
        } else {
          if (mode == GameScoreMode.best) {
            hasMoreData = isSchool
                ? ref
                    .watch(bestScoreSchoolRankingProvider(
                        (gameId: type, schoolId: schoolId!)).notifier)
                    .hasMoreData
                : ref
                    .watch(bestScoreNationwideRankingProvider(type).notifier)
                    .hasMoreData;
          } else {
            hasMoreData = isSchool
                ? ref
                    .watch(totalScoreSchoolRankingProvider(
                        (gameId: type, schoolId: schoolId!)).notifier)
                    .hasMoreData
                : ref
                    .watch(totalScoreNationwideRankingProvider(type).notifier)
                    .hasMoreData;
          }
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8.0), // 목록 상하 여백 추가
            itemCount: users.length + 1,
            itemBuilder: (context, index) {
              if (index == users.length) {
                return hasMoreData
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()))
                    : const SizedBox(height: 40);
              }

              final user = users[index];
              final rank = index + 1;
              final isMe = user.uid == myUid;
              final int score;

              if (widget.selectedType == 'overall_score') {
                score = (widget.selectedMode == GameScoreMode.best
                    ? user.score_best_personal
                    : user.score_total_personal);
              } else {
                score = (widget.selectedMode == GameScoreMode.best
                        ? user.bestScoresByGame[widget.selectedType]
                        : user.totalScoresByGame[widget.selectedType]) ??
                    0;
              }

              // ⭐️ [수정 3] : ListTile을 Card로 감싸서 스타일 적용
              return Card(
                color: Colors.white.withAlpha(190), // 반투명 흰색 배경
                elevation: 0, // 그림자 제거
                shape: RoundedRectangleBorder(
                  // 모서리 둥글게
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    // isMe 하이라이트도 둥글게
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: isMe
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha((255 * 0.15).round()) // 투명도 약간 진하게 수정
                      : null,
                  leading: Text('$rank',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                  title: Text(user.nickname,
                      style: TextStyle(
                          fontWeight:
                              isMe ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(user.schoolName),
                  trailing: Text('${formatter.format(score)} 점', // 포맷 적용
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(
          child: Text(
              '랭킹을 불러오는 중 오류가 발생했습니다.\nFirestore 색인이 올바르게 설정되었는지 확인해주세요.\n\nError: ${e.toString()}')),
    );
  }
}
