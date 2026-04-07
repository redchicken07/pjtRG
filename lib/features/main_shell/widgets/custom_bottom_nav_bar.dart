// lib/features/main_shell/widgets/custom_bottom_nav_bar.dart
import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: '홈',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.games_outlined), // "게임하기" 아이콘
          label: '게임하기', // "문제풀기"에서 변경
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.school),
          label: '학교랭킹',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '개인랭킹',
        ),
      ],
    );
  }
}
