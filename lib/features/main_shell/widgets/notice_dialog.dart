import 'package:flutter/material.dart';
import 'package:ranking_ground_v1/data/models/notice_model.dart';

Future<void> showNoticeDialog({
  required BuildContext context,
  required NoticeModel notice,
  required Future<void> Function() onDoNotShowToday,
  bool barrierDismissible = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AlertDialog(
      title: Text(notice.title),
      content: SingleChildScrollView(child: Text(notice.message)),
      actions: [
        TextButton(
          onPressed: () async {
            await onDoNotShowToday();
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
          child: const Text('오늘 하루 보지 않기'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}
