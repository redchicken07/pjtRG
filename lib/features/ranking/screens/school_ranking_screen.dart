// lib/features/ranking/screens/school_ranking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ranking_ground_v1/features/ranking/providers/ranking_school_provider.dart';
import 'package:intl/intl.dart'; // 숫자 포맷팅을 위해 import

class SchoolRankingScreen extends ConsumerStatefulWidget {
  const SchoolRankingScreen({super.key});

  @override
  ConsumerState<SchoolRankingScreen> createState() =>
      _SchoolRankingScreenState();
}

class _SchoolRankingScreenState extends ConsumerState<SchoolRankingScreen>
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
    final mySchoolAsync = ref.watch(userSchoolProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '전국 랭킹'),
            Tab(text: '우리 지역 랭킹'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            // --- ⭐️ 수정된 부분 1: 배경에 투명도 적용 ⭐️ ---
            child: Opacity(
              opacity: 0.9, // 0.0(투명) ~ 1.0(불투명) 사이의 값으로 조절
              child: Image.asset(
                'assets/background_ranking_school.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.grey.shade200),
              ),
            ),
          ),
          TabBarView(
            controller: _tabController,
            children: [
              // 전국 랭킹 탭
              const _RankingList(isCityRanking: false),

              // 우리 지역 랭킹 탭
              mySchoolAsync.when(
                data: (mySchool) {
                  if (mySchool?.city == null || mySchool!.city.isEmpty) {
                    return const Center(
                        child: Text(
                            '소속된 학교의 지역 정보가 없습니다.\nMy Page에서 학교를 설정해주세요.'));
                  }
                  return _RankingList(isCityRanking: true, city: mySchool.city);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) =>
                    const Center(child: Text("사용자 학교 정보를 가져오는데 실패했습니다.")),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankingList extends ConsumerStatefulWidget {
  final bool isCityRanking;
  final String? city;

  const _RankingList({required this.isCityRanking, this.city});

  @override
  ConsumerState<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends ConsumerState<_RankingList> {
  final _scrollController = ScrollController();
  final formatter = NumberFormat('#,###');

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
        _scrollController.position.maxScrollExtent - 300) {
      return;
    }

    if (widget.isCityRanking) {
      ref
          .read(citySchoolRankingProvider(widget.city!).notifier)
          .fetchNextPage();
    } else {
      ref.read(schoolRankingNotifierProvider.notifier).fetchNextPage();
    }
  }

  Future<void> _handleRefresh() async {
    if (widget.isCityRanking) {
      await ref
          .read(citySchoolRankingProvider(widget.city!).notifier)
          .refresh();
    } else {
      await ref.read(schoolRankingNotifierProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankingAsync = widget.isCityRanking
        ? ref.watch(citySchoolRankingProvider(widget.city!))
        : ref.watch(schoolRankingNotifierProvider);

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: rankingAsync.when(
        data: (schools) {
          if (schools.isEmpty) {
            return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: const Center(child: Text('랭킹 정보가 없습니다.'))),
                    ));
          }
          // --- ⭐️ 수정된 부분 2: ListView -> ListView.separated 로 변경하여 구분선 추가 ⭐️ ---
          return ListView.separated(
            controller: _scrollController,
            itemCount: schools.length + 1,
            padding: const EdgeInsets.symmetric(vertical: 8.0), // 목록의 상하 여백
            separatorBuilder: (context, index) =>
                const SizedBox(height: 4), // 아이템 간 간격
            itemBuilder: (context, index) {
              if (index == schools.length) {
                final bool hasMore;
                if (widget.isCityRanking) {
                  hasMore = ref
                      .watch(citySchoolRankingProvider(widget.city!).notifier)
                      .hasMoreData;
                } else {
                  hasMore = ref
                      .watch(schoolRankingNotifierProvider.notifier)
                      .hasMoreData;
                }

                return hasMore
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()))
                    : const SizedBox(height: 40);
              }

              final school = schools[index];
              final rankDisplay = widget.isCityRanking
                  ? (index + 1).toString()
                  : (school.overallRank?.toString() ?? (index + 1).toString());

              // --- ⭐️ 수정된 부분 3: ListTile을 Card로 감싸 가독성 향상 ⭐️ ---
              return Card(
                color: Colors.white.withAlpha(190), // 반투명 흰색 배경
                elevation: 1, // 약간의 그림자 효과
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: ListTile(
                  leading: Text(rankDisplay,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold, // 순위 텍스트도 강조
                          )),
                  title: Text(school.schoolName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)), // 학교 이름 강조
                  subtitle: Text(school.address,
                      style: Theme.of(context).textTheme.bodySmall),
                  trailing: Text(
                      '${formatter.format(school.scoreTotal ?? 0)} 점', // 포맷 적용
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold) // 점수 강조
                      ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('학교 랭킹을 불러오지 못했습니다.'),
              Text(err.toString(),
                  style: Theme.of(context).textTheme.bodySmall),
              ElevatedButton(
                  onPressed: _handleRefresh, child: const Text("재시도"))
            ],
          ),
        ),
      ),
    );
  }
}
