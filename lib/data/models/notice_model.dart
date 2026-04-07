// lib/data/models/notice_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String id;
  final String title;
  final String message;
  final int version;
  final bool isActive;

  NoticeModel({
    required this.id,
    required this.title,
    required this.message,
    required this.version,
    required this.isActive,
  });

  factory NoticeModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NoticeModel(
      id: doc.id,
      title: data['title'] ?? '공지사항',
      message: data['message'] ?? '내용이 없습니다.',
      version: data['version'] ?? 1,
      isActive: data['isActive'] ?? false,
    );
  }
}
