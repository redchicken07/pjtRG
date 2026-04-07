// lib/data/models/school_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolModel {
  final String id;
  final String schoolName;
  final String city;
  final String address;
  final String type;
  final int? scoreTotal;
  final int? overallRank; // 전체 학교 순위 필드
  final Timestamp? rankCalculatedAt;

  SchoolModel({
    required this.id,
    required this.schoolName,
    required this.city,
    required this.address,
    required this.type,
    this.scoreTotal,
    this.overallRank, // 생성자에 추가
    this.rankCalculatedAt,
  });

  factory SchoolModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SchoolModel(
      id: doc.id,
      schoolName: data['school_name'] ?? '',
      city: data['city'] ?? '',
      address: data['address'] ?? '',
      type: data['type'] ?? '기타',
      scoreTotal: data['score_total'] as int?,
      overallRank: data['overallRank'] as int?, // Firestore에서 읽기
      rankCalculatedAt: data['rankCalculatedAt'] as Timestamp?,
    );
  }
}
