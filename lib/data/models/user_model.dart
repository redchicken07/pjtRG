// lib/data/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String nickname;
  final String schoolId;
  final String schoolName;
  final String grade;
  final String? profileImageUrl;
  final Timestamp? createdAt;
  final Timestamp? profileLastUpdatedAt; // ◀️ 추가
  final Timestamp? rankCalculatedAt;

// ignore: non_constant_identifier_names
  final int score_best_personal;
// ignore: non_constant_identifier_names
  final int score_total_personal;

  final Map<String, int> bestScoresByGame;
  final Map<String, int> totalScoresByGame;

  final int? overallRank;
  final int? schoolRank;

  UserModel({
    required this.uid,
    required this.email,
    required this.nickname,
    required this.schoolId,
    required this.schoolName,
    required this.grade,
    this.profileImageUrl,
    this.createdAt,
    this.profileLastUpdatedAt, // ◀️ 추가
    this.rankCalculatedAt,
    // ignore: non_constant_identifier_names
    required this.score_best_personal,
    // ignore: non_constant_identifier_names
    required this.score_total_personal,
    this.bestScoresByGame = const {},
    this.totalScoresByGame = const {},
    this.overallRank,
    this.schoolRank,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    Map<String, int> bestScoresMap = {};
    if (map['best_scores_by_game'] is Map) {
      (map['best_scores_by_game'] as Map).forEach((key, value) {
        if (value is num) bestScoresMap[key.toString()] = value.toInt();
      });
    }

    Map<String, int> totalScoresMap = {};
    if (map['total_scores_by_game'] is Map) {
      (map['total_scores_by_game'] as Map).forEach((key, value) {
        if (value is num) totalScoresMap[key.toString()] = value.toInt();
      });
    }

    return UserModel(
      uid: documentId,
      email: (map['email']?.toString()) ?? '',
      nickname: (map['nickname']?.toString()) ?? '',
      schoolId: (map['schoolId']?.toString()) ?? '',
      schoolName: (map['school_name']?.toString()) ?? '',
      grade: (map['grade']?.toString()) ?? '기타학생',
      profileImageUrl: map['profileImageUrl']?.toString(),
      createdAt: map['createdAt'] as Timestamp?,
      profileLastUpdatedAt: map['profileLastUpdatedAt'] as Timestamp?, // ◀️ 추가
      rankCalculatedAt: map['rankCalculatedAt'] as Timestamp?,
      score_best_personal: (map['score_best_personal'] is num
          ? (map['score_best_personal'] as num).toInt()
          : 0),
      score_total_personal: (map['score_total_personal'] is num
          ? (map['score_total_personal'] as num).toInt()
          : 0),
      bestScoresByGame: bestScoresMap,
      totalScoresByGame: totalScoresMap,
      overallRank: (map['overallRank'] is num
          ? (map['overallRank'] as num).toInt()
          : null),
      schoolRank: (map['schoolRank'] is num
          ? (map['schoolRank'] as num).toInt()
          : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'schoolId': schoolId,
      'school_name': schoolName,
      'grade': grade,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'score_best_personal': score_best_personal,
      'score_total_personal': score_total_personal,
      'best_scores_by_game': bestScoresByGame,
      'total_scores_by_game': totalScoresByGame,
    };
  }
}
