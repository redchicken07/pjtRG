// lib/features/main_shell/screens/home_tab_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ranking_ground_v1/data/models/school_model.dart';
import 'package:ranking_ground_v1/data/models/user_model.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/ranking/providers/ranking_school_provider.dart';
import 'package:ranking_ground_v1/features/ranking/providers/ranking_personal_provider.dart';
import 'package:intl/intl.dart';

class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});
  static const Duration _rankRefreshInterval = Duration(hours: 24);

  bool _isRankFresh(Timestamp? rankCalculatedAt) {
    if (rankCalculatedAt == null) return false;
    return DateTime.now().difference(rankCalculatedAt.toDate()) <=
        _rankRefreshInterval;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topSchools = ref.watch(topSchoolRankingProvider);
    final topPlayers = ref.watch(topPersonalRankingProvider);
    final currentUserProfileAsyncValue = ref.watch(userProfileProvider);
    final userSchoolAsyncValue = ref.watch(userSchoolProvider);
    final schoolInternalTopPlayers =
        ref.watch(schoolInternalTopRankingProvider);
    final formatter = NumberFormat('#,###');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.65,
              child: Image.asset(
                'assets/background_home.png',
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error,
                    StackTrace? stackTrace) {
                  debugPrint(
                      '!!! HomeTabScreen: Failed to load background_home.png: $error');
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Text(
                        '배경 이미지 로드 실패',
                        style: TextStyle(color: Colors.black45),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                currentUserProfileAsyncValue.when(
                  data: (currentUserProfile) {
                    if (currentUserProfile == null) {
                      return _buildInfoCard(
                        context,
                        '나의 랭킹 정보',
                        '현재 랭킹을 집계 중입니다.',
                        minHeight: 200,
                      );
                    }
                    return Card(
                      color: Colors.white.withAlpha(150),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionTitle(
                              context,
                              '🚀 나의 현재 랭킹 (누적 점수 기준)',
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 2.0, bottom: 8.0),
                              child: Text(
                                '랭킹 정보는 24시간 주기로 업데이트 됩니다.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            _buildInfoCard(
                              context,
                              '나의 전체 개인 순위',
                              (currentUserProfile.overallRank != null &&
                                      currentUserProfile.overallRank! > 0 &&
                                      _isRankFresh(
                                          currentUserProfile.rankCalculatedAt))
                                  ? '${currentUserProfile.nickname}님: ${currentUserProfile.overallRank} 위'
                                  : '${currentUserProfile.nickname}님: 집계 중 (24시간 주기)',
                              minHeight: 70,
                            ),
                            const SizedBox(height: 8),
                            userSchoolAsyncValue.when(
                              data: (mySchool) {
                                if (mySchool == null) {
                                  return _buildInfoCard(
                                    context,
                                    '우리 학교 전체 순위',
                                    '학교 미등록',
                                    minHeight: 70,
                                  );
                                }
                                return _buildInfoCard(
                                  context,
                                  '${mySchool.schoolName} 전체 순위',
                                  (mySchool.overallRank != null &&
                                          mySchool.overallRank! > 0 &&
                                          _isRankFresh(
                                              mySchool.rankCalculatedAt))
                                      ? '${mySchool.overallRank} 위'
                                      : '집계 중 (24시간 주기)',
                                  minHeight: 70,
                                );
                              },
                              loading: () => _buildInfoCard(
                                context,
                                '우리 학교 전체 순위',
                                '학교 정보 로딩 중...',
                                minHeight: 70,
                              ),
                              error: (e, s) => _buildInfoCard(
                                context,
                                '우리 학교 전체 순위',
                                '학교 정보 오류',
                                minHeight: 70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoCard(
                              context,
                              '나의 학교 내 순위',
                              (currentUserProfile.schoolRank != null &&
                                      currentUserProfile.schoolRank! > 0 &&
                                      _isRankFresh(
                                          currentUserProfile.rankCalculatedAt))
                                  ? '${currentUserProfile.schoolRank} 위'
                                  : '집계 중 (24시간 주기)',
                              minHeight: 70,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, s) => _buildInfoCard(
                    context,
                    '나의 랭킹 정보',
                    '사용자 정보 로드 오류',
                    minHeight: 150,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.black38, thickness: 1),
                const SizedBox(height: 16),
                _buildSectionTitle(context, '🏆 전체 학교 랭킹 Top 5 (누적 점수)'),
                _buildRankingList<SchoolModel>(
                  data: topSchools,
                  itemBuilder: (ctx, school, index) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.black.withAlpha(20),
                      child: Text('${index + 1}',
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(school.schoolName,
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                    subtitle: Text(school.address,
                        style: TextStyle(color: Colors.grey.shade800)),
                    trailing: Text(
                      '${formatter.format(school.scoreTotal ?? 0)}점',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  buildContext: context,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle(context, '🌟 전체 개인 랭킹 Top 5 (누적 점수)'),
                _buildRankingList<UserModel>(
                  data: topPlayers,
                  itemBuilder: (ctx, player, index) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.black.withAlpha(20),
                      child: Text('${index + 1}',
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(player.nickname,
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      player.schoolName,
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                    trailing: Text(
                      '${formatter.format(player.score_total_personal)}점',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  buildContext: context,
                ),
                const SizedBox(height: 32),
                currentUserProfileAsyncValue.when(
                  data: (currentUserProfile) {
                    if (currentUserProfile?.schoolId != null &&
                        currentUserProfile!.schoolId.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: Colors.black38, thickness: 1),
                          const SizedBox(height: 16),
                          _buildSectionTitle(context,
                              '🔥 ${currentUserProfile.schoolName} Top 10 (누적 점수)'),
                          _buildRankingList<UserModel>(
                            data: schoolInternalTopPlayers,
                            itemBuilder: (ctx, player, index) {
                              final isCurrentUser =
                                  player.uid == currentUserProfile.uid;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isCurrentUser
                                      ? Colors.amber.shade200
                                      : Colors.black.withAlpha(20),
                                  child: Text('${index + 1}',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold)),
                                ),
                                title: Text(player.nickname,
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: isCurrentUser
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                                subtitle: Text(
                                  player.grade,
                                  style: TextStyle(color: Colors.grey.shade800),
                                ),
                                trailing: Text(
                                  '${formatter.format(player.score_total_personal)}점',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            },
                            buildContext: context,
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildRankingList<T>({
    required AsyncValue<List<T>> data,
    required Widget Function(BuildContext context, T item, int index)
        itemBuilder,
    required BuildContext buildContext,
  }) {
    return data.when(
      data: (items) {
        if (items.isEmpty) {
          return _buildInfoCard(buildContext, '랭킹 정보 없음', '아직 랭킹 데이터가 없습니다.',
              minHeight: 80);
        }
        return Card(
          color: Colors.white.withAlpha(150),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                itemBuilder(context, items[index], index),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 30.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => _buildErrorCard(buildContext, '랭킹을 불러오지 못했습니다.'),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String subtitle,
      {double? minHeight}) {
    return Card(
      color: Colors.white.withAlpha(150),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        constraints:
            minHeight != null ? BoxConstraints(minHeight: minHeight) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (subtitle.isNotEmpty) const SizedBox(height: 4),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                    textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Card(
      color: Colors.redAccent.withAlpha(200),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
