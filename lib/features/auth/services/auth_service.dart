// lib/features/auth/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ranking_ground_v1/data/models/school_model.dart';
import 'package:ranking_ground_v1/data/models/user_model.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  fb_auth.User? get currentUser => _firebaseAuth.currentUser;
  Stream<fb_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  // ⭐️ [추가] UserProfileNotifier에서 호출할 메서드
  // DocumentSnapshot 자체를 반환하여 존재 여부를 확인할 수 있게 합니다.
  Future<DocumentSnapshot> getUserProfileDocument(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot userDoc = await getUserProfileDocument(uid);
      if (userDoc.exists && userDoc.data() != null) {
        return UserModel.fromMap(userDoc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print(
            "AuthService: Error fetching user profile for $uid: ${e.toString()}");
      }
      return null;
    }
  }

  Future<bool> isNicknameAvailable(String nickname) async {
    if (nickname.trim().isEmpty) return false;
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('nickname', isEqualTo: nickname.trim())
          .limit(1)
          .get();
      return result.docs.isEmpty;
    } catch (e) {
      if (kDebugMode) {
        print(
            "AuthService: Error checking nickname availability: ${e.toString()}");
      }
      return false;
    }
  }

  Future<fb_auth.UserCredential?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String nickname,
    required SchoolModel selectedSchool,
    required String grade,
  }) async {
    try {
      fb_auth.UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      fb_auth.User? firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(nickname);
        UserModel newUser = UserModel(
          uid: firebaseUser.uid,
          email: email,
          nickname: nickname,
          schoolId: selectedSchool.id,
          schoolName: selectedSchool.schoolName,
          grade: grade,
          createdAt: Timestamp.now(),
          score_best_personal: 0,
          score_total_personal: 0,
          bestScoresByGame: {},
          totalScoresByGame: {},
        );
        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(newUser.toMap());
        return userCredential;
      }
      return null;
    } on fb_auth.FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('회원가입 중 알 수 없는 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> updateProfile({
    required String uid,
    String? nickname,
    SchoolModel? school,
    String? grade,
  }) async {
    final Map<String, dynamic> updates = {};
    final currentUser = _firebaseAuth.currentUser;

    if (nickname != null && nickname.isNotEmpty) {
      updates['nickname'] = nickname;
    }
    if (school != null) {
      updates['schoolId'] = school.id;
      updates['school_name'] = school.schoolName;
    }
    if (grade != null && grade.isNotEmpty) {
      updates['grade'] = grade;
    }

    if (updates.isNotEmpty) {
      updates['profileLastUpdatedAt'] = FieldValue.serverTimestamp();
    }

    try {
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
      if (currentUser != null &&
          nickname != null &&
          nickname.isNotEmpty &&
          currentUser.displayName != nickname) {
        await currentUser.updateDisplayName(nickname);
      }
    } on fb_auth.FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('프로필 업데이트 중 알 수 없는 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> recordGameResult({
    required String userId,
    required String gameId,
    required int pointsEarnedInSession,
    required String schoolId,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final schoolRef = _firestore.collection('schools').doc(schoolId);

    try {
      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw Exception("User not found");

        final userData = userSnapshot.data() as Map<String, dynamic>;

        final bestScoresMap =
            Map<String, int>.from(userData['best_scores_by_game'] ?? {});
        final totalScoresMap =
            Map<String, int>.from(userData['total_scores_by_game'] ?? {});

        final previousBest = bestScoresMap[gameId] ?? 0;
        int bestScoreDelta = 0;
        if (pointsEarnedInSession > previousBest) {
          bestScoresMap[gameId] = pointsEarnedInSession;
          bestScoreDelta = pointsEarnedInSession - previousBest;
        }

        final previousTotal = totalScoresMap[gameId] ?? 0;
        totalScoresMap[gameId] = previousTotal + pointsEarnedInSession;

        transaction.update(userRef, {
          'best_scores_by_game': bestScoresMap,
          'total_scores_by_game': totalScoresMap,
          'score_best_personal': FieldValue.increment(bestScoreDelta),
          'score_total_personal': FieldValue.increment(pointsEarnedInSession),
        });

        if (schoolId.isNotEmpty) {
          transaction.update(schoolRef,
              {'score_total': FieldValue.increment(pointsEarnedInSession)});
        }
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("AuthService: Error recording game result: ${e.toString()}");
        print(stackTrace);
      }
      throw Exception('게임 결과 저장 중 오류 발생');
    }
  }

  Future<List<SchoolModel>> searchSchools(String query) async {
    if (query.trim().isEmpty || query.trim().length < 2) return [];
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('schools')
          .where('school_name', isGreaterThanOrEqualTo: query.trim())
          .where('school_name', isLessThanOrEqualTo: '${query.trim()}\uf8ff')
          .orderBy('school_name')
          .limit(15)
          .get();
      return snapshot.docs
          .map((doc) => SchoolModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) print('!!! AuthService_학교 검색 중 에러 발생: ${e.toString()}');
      return [];
    }
  }

  Future<fb_auth.UserCredential?> signInWithEmailPassword(
      String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
    } on fb_auth.FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('로그인 중 알 수 없는 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<SchoolModel?> getSchoolById(String schoolId) async {
    if (schoolId.isEmpty) return null;
    try {
      final docSnapshot =
          await _firestore.collection('schools').doc(schoolId).get();
      if (docSnapshot.exists) {
        return SchoolModel.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('!!! AuthService_학교 정보 가져오기 에러: ${e.toString()}');
      }
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('로그아웃 중 오류가 발생했습니다: ${e.toString()}');
    }
  }
}
