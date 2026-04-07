// lib/features/main_shell/providers/main_shell_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mainShellTabIndexProvider = StateProvider<int>((ref) {
  // 앱 시작 시 기본으로 선택될 탭 인덱스 (0은 보통 '홈' 탭)
  return 0;
});
