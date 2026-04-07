// lib/features/main_shell/widgets/notice_dialog_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ranking_ground_v1/features/main_shell/providers/notice_provider.dart';
import 'package:ranking_ground_v1/features/main_shell/widgets/notice_dialog.dart';

class NoticeDialogWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const NoticeDialogWrapper({super.key, required this.child});

  @override
  ConsumerState<NoticeDialogWrapper> createState() =>
      _NoticeDialogWrapperState();
}

class _NoticeDialogWrapperState extends ConsumerState<NoticeDialogWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowNotice());
  }

  Future<void> _checkAndShowNotice() async {
    try {
      final notice = await ref.read(noticeProvider.future);
      if (notice != null && mounted) {
        await showNoticeDialog(
          context: context,
          notice: notice,
          onDoNotShowToday: () =>
              ref.read(noticeServiceProvider).setDoNotShowToday(notice.version),
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Notice check failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이 위젯은 UI를 직접 그리지 않고, 자식 위젯을 그대로 반환합니다.
    return widget.child;
  }
}
