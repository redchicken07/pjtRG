// lib/features/main_shell/providers/notice_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ranking_ground_v1/data/models/notice_model.dart';

const _prodNoticesCollection = 'app_notices';
const _debugNoticesCollection = 'app_notices_debug';
const _lastSeenNoticeVersionKey = 'lastSeenNoticeVersion';
const _lastSeenNoticeDateKey = 'lastSeenNoticeDate';
const _lastSeenDebugNoticeVersionKey = 'lastSeenDebugNoticeVersion';
const _lastSeenDebugNoticeDateKey = 'lastSeenDebugNoticeDate';

// Provider to fetch the latest active notice
final noticeProvider = FutureProvider.autoDispose<NoticeModel?>((ref) async {
  final firestore = FirebaseFirestore.instance;
  final snapshot = await firestore
      .collection(_prodNoticesCollection)
      .where('isActive', isEqualTo: true)
      .orderBy('version', descending: true)
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) {
    return null; // 활성화된 공지 없음
  }

  final notice = NoticeModel.fromFirestore(snapshot.docs.first);

  // '오늘 하루 보지 않기' 확인
  final prefs = await SharedPreferences.getInstance();
  final lastSeenVersion = prefs.getInt(_lastSeenNoticeVersionKey) ?? 0;
  final lastSeenDate = prefs.getString(_lastSeenNoticeDateKey) ?? '';

  final today = DateTime.now().toIso8601String().substring(0, 10);

  if (notice.version == lastSeenVersion && lastSeenDate == today) {
    return null; // 오늘 이미 본 공지
  }

  return notice;
});

// '오늘 하루 보지 않기' 저장 로직
final noticeServiceProvider = Provider((ref) => NoticeService());

class NoticeService {
  Future<void> setDoNotShowToday(int version) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setInt(_lastSeenNoticeVersionKey, version);
    await prefs.setString(_lastSeenNoticeDateKey, today);
  }

  Future<void> setDoNotShowTodayForDebug(int version) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setInt(_lastSeenDebugNoticeVersionKey, version);
    await prefs.setString(_lastSeenDebugNoticeDateKey, today);
  }

  Future<void> resetDoNotShowToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSeenNoticeVersionKey);
    await prefs.remove(_lastSeenNoticeDateKey);
  }

  Future<void> resetDebugDoNotShowToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSeenDebugNoticeVersionKey);
    await prefs.remove(_lastSeenDebugNoticeDateKey);
  }

  Future<int> createDebugSampleNotice() async {
    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final version = now.millisecondsSinceEpoch;
    await firestore
        .collection(_debugNoticesCollection)
        .doc('debug_$version')
        .set({
      'title': '[테스트 공지] 시스템 점검 안내',
      'message':
          '테스트 공지입니다.\\n생성 시각: ${now.toIso8601String()}\\n\\n이 문서는 디버그 검증 용도로 생성되었습니다.',
      'version': version,
      'isActive': true, // 디버그 컬렉션 내부에서만 사용
      'createdAt': FieldValue.serverTimestamp(),
    });
    return version;
  }

  Future<NoticeModel?> fetchLatestDebugNotice() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection(_debugNoticesCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('version', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final notice = NoticeModel.fromFirestore(snapshot.docs.first);
    final prefs = await SharedPreferences.getInstance();
    final lastSeenVersion = prefs.getInt(_lastSeenDebugNoticeVersionKey) ?? 0;
    final lastSeenDate = prefs.getString(_lastSeenDebugNoticeDateKey) ?? '';
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (notice.version == lastSeenVersion && lastSeenDate == today) {
      return null;
    }
    return notice;
  }
}
