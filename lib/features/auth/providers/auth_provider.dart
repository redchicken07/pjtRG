// lib/features/auth/providers/auth_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ranking_ground_v1/features/auth/services/auth_service.dart';
import 'package:ranking_ground_v1/data/models/school_model.dart';
import 'package:ranking_ground_v1/data/models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateChangesProvider = StreamProvider<fb_auth.User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<UserModel?>>((ref) {
  return UserProfileNotifier(ref);
});

class UserProfileNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final Ref _ref;
  StreamSubscription<fb_auth.User?>? _authStateSubscription;

  UserProfileNotifier(this._ref) : super(const AsyncValue.loading()) {
    final initialUser = _ref.read(authServiceProvider).currentUser;
    if (initialUser != null) {
      _fetchUserProfile(initialUser.uid);
    } else {
      state = const AsyncValue.data(null);
    }

    _authStateSubscription =
        _ref.watch(authServiceProvider).authStateChanges.listen((firebaseUser) {
      if (!mounted) return;

      final currentUid = state.asData?.value?.uid;

      if (firebaseUser != null) {
        if (currentUid != firebaseUser.uid ||
            state is! AsyncData ||
            state.asData?.value == null) {
          _fetchUserProfile(firebaseUser.uid);
        }
      } else {
        if (state.asData?.value != null) {
          state = const AsyncValue.data(null);
        }
      }
    });
  }

  // ⭐️ [수정] 재시도 로직이 포함된 새로운 _fetchUserProfile 함수
  Future<void> _fetchUserProfile(String uid) async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    try {
      DocumentSnapshot? userDoc;
      int retries = 0;
      const maxRetries = 5; // 최대 5번 재시도
      const delay = Duration(milliseconds: 200); // 0.2초 간격

      // Firestore 문서가 생성될 때까지 짧게 대기하며 재시도
      while (retries < maxRetries) {
        userDoc =
            await _ref.read(authServiceProvider).getUserProfileDocument(uid);
        if (userDoc.exists) {
          break; // 문서를 찾으면 루프 종료
        }
        retries++;
        if (kDebugMode) {
          print(
              'User document not found for $uid. Retry $retries/$maxRetries...');
        }
        await Future.delayed(delay);
      }

      if (!mounted) return;

      if (userDoc != null && userDoc.exists) {
        final userProfile =
            UserModel.fromMap(userDoc.data() as Map<String, dynamic>, uid);
        state = AsyncValue.data(userProfile);
      } else {
        // 재시도 후에도 문서를 찾지 못하면 null 처리
        if (kDebugMode) {
          print(
              'Failed to find user document for $uid after $maxRetries retries.');
        }
        state = const AsyncValue.data(null);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error in _fetchUserProfile: $e');
      }
      if (!mounted) return;
      state = AsyncValue.error(e, stackTrace);
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}

// SignUpController, LoginController 등은 원래 코드로 유지합니다.
// (즉, bool을 반환하고 ref.listen에서 context.go를 호출하는 방식)
class SignUpController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  SignUpController(this._authService) : super(const AsyncValue.data(null));

  Future<bool> signUp({
    required String email,
    required String password,
    required String nickname,
    required SchoolModel selectedSchool,
    required String grade,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signUpWithEmailPassword(
        email: email,
        password: password,
        nickname: nickname,
        selectedSchool: selectedSchool,
        grade: grade,
      );
      if (!mounted) return false;
      state = const AsyncValue.data(null);
      return true;
    } on fb_auth.FirebaseAuthException catch (e, stackTrace) {
      if (!mounted) return false;
      state = AsyncValue.error(mapAuthErrorCodeToMessage(e.code), stackTrace);
      return false;
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      if (!mounted) return false;
      state =
          AsyncValue.error('알 수 없는 회원가입 오류가 발생했습니다: $errorMessage', stackTrace);
      return false;
    }
  }
}

final signUpControllerProvider =
    StateNotifierProvider.autoDispose<SignUpController, AsyncValue<void>>(
  (ref) => SignUpController(ref.watch(authServiceProvider)),
);

class LoginController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  LoginController(this._authService) : super(const AsyncValue.data(null));

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signInWithEmailPassword(email, password);
      if (!mounted) return false;
      state = const AsyncValue.data(null);
      return true;
    } on fb_auth.FirebaseAuthException catch (e, stackTrace) {
      if (!mounted) return false;
      state = AsyncValue.error(mapAuthErrorCodeToMessage(e.code), stackTrace);
      return false;
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      if (!mounted) return false;
      state =
          AsyncValue.error('알 수 없는 로그인 오류가 발생했습니다: $errorMessage', stackTrace);
      return false;
    }
  }
}

final loginControllerProvider =
    StateNotifierProvider.autoDispose<LoginController, AsyncValue<void>>(
  (ref) => LoginController(ref.watch(authServiceProvider)),
);

final schoolSearchProvider =
    FutureProvider.autoDispose.family<List<SchoolModel>, String>(
  (ref, query) async {
    if (query.trim().isEmpty || query.trim().length < 2) {
      return [];
    }
    return ref.watch(authServiceProvider).searchSchools(query);
  },
);

String mapAuthErrorCodeToMessage(String errorCode) {
  switch (errorCode) {
    case 'user-not-found':
      return '등록되지 않은 계정입니다.';
    case 'wrong-password':
      return '비밀번호가 틀렸습니다.';
    case 'email-already-in-use':
      return '이미 사용 중인 이메일입니다.';
    case 'invalid-email':
      return '유효하지 않은 이메일 형식입니다.';
    case 'weak-password':
      return '비밀번호는 6자 이상이어야 합니다.';
    case 'operation-not-allowed':
      return '이메일/비밀번호 로그인이 활성화되지 않았습니다.';
    case 'invalid-credential':
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    default:
      return '오류가 발생했습니다. (코드: $errorCode)';
  }
}

class EditProfileController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  EditProfileController(this._ref) : super(const AsyncValue.data(null));

  Future<bool> updateProfile({
    required String uid,
    String? nickname,
    SchoolModel? school,
    String? grade,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(authServiceProvider).updateProfile(
            uid: uid,
            nickname: nickname,
            school: school,
            grade: grade,
          );
      if (!mounted) return false;
      _ref.invalidate(userProfileProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stackTrace) {
      if (!mounted) return false;
      state = AsyncValue.error('프로필 업데이트 실패: ${e.toString()}', stackTrace);
      return false;
    }
  }
}

final editProfileControllerProvider =
    StateNotifierProvider.autoDispose<EditProfileController, AsyncValue<void>>(
  (ref) => EditProfileController(ref),
);

final schoolDetailsProvider =
    FutureProvider.autoDispose.family<SchoolModel?, String>((ref, schoolId) {
  if (schoolId.trim().isEmpty) {
    return Future.value(null);
  }
  return ref.watch(authServiceProvider).getSchoolById(schoolId);
});
