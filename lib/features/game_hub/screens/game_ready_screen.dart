// lib/features/game_hub/screens/game_ready_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/data/models/user_model.dart';
import 'package:intl/intl.dart'; // 숫자 포맷팅을 위해 import

class GameReadyScreen extends ConsumerWidget {
  const GameReadyScreen({super.key});

  final List<Map<String, dynamic>> gameTypes = const [
    {
      'id': 'memory_maze_game',
      'name': '메모리 미로',
      'description': '미로를 외운 뒤, 보이지 않는 길을 찾아 탈출하세요!',
      'icon': Icons.memory,
      'route': '/game_hub/memory_maze_game/play',
    },
    {
      'id': 'follow_arrows_game',
      'name': '화살표 따라가기',
      'description': '나타나는 화살표 방향으로 빠르게 버튼을 누르세요!',
      'icon': Icons.multiple_stop_rounded,
      'route': '/game_hub/follow_arrows_game/play',
    },
    {
      // --- 수정된 부분 ---
      'id': 'game_1024',
      'name': '1024 퍼즐 게임',
      'description': '4x4 그리드에서 타일을 합쳐 1024를 만들어보세요!',
      'icon': Icons.grid_on_outlined,
      'route': '/game_hub/1024_game/play',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ... (이하 코드는 변경 없음)
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final userModelAsync = ref.watch(userProfileProvider);
    final formatter = NumberFormat('#,###');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background_game_ready.png',
                fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withAlpha(70)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    '도전할 게임을 선택하세요!',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: userModelAsync.when(
                      data: (UserModel? userModel) {
                        final scoresMap =
                            userModel?.bestScoresByGame ?? <String, int>{};
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: gameTypes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final game = gameTypes[index];
                            final gameId = game['id'] as String;
                            final bestScore = scoresMap[gameId] ?? 0;

                            return Card(
                              color: Colors.white.withAlpha(190),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  final route = game['route'] as String?;
                                  if (route != null && route.isNotEmpty) {
                                    context.go(route);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16.0, horizontal: 16.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(game['icon'] as IconData,
                                          size: 68, color: colorScheme.primary),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(game['name'] as String,
                                                style: textTheme.titleLarge
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 22,
                                                        color: Colors.black87)),
                                            const SizedBox(height: 6),
                                            Text(game['description'] as String,
                                                style: textTheme.bodyLarge
                                                    ?.copyWith(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black87)),
                                            const SizedBox(height: 8),
                                            Text(
                                                '나의 최고 기록: ${formatter.format(bestScore)} 점', // 포맷 적용
                                                style: textTheme.bodyLarge
                                                    ?.copyWith(
                                                        fontSize: 16,
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Colors.grey,
                                          size: 24),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                      error: (err, stack) => Center(
                        child: Text('사용자 정보를 불러오는 중 오류가 발생했습니다.',
                            style: textTheme.bodyMedium
                                ?.copyWith(color: Colors.white),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
