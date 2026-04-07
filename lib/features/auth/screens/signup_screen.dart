// lib/features/auth/screens/signup_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/data/models/school_model.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _schoolSearchController = TextEditingController();

  SchoolModel? _selectedSchool;
  String _searchQuery = "";
  Timer? _debounce;

  String? _selectedGrade;
  List<String> _availableGrades = [];

  bool _isPrivacyPolicyAgreed = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _schoolSearchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && query.trim() != _searchQuery) {
        setState(() {
          _searchQuery = query.trim();
          _selectedSchool = null;
          _availableGrades = [];
          _selectedGrade = null;
        });
      }
    });
  }

  void _updateAvailableGrades(SchoolModel school) {
    if (!mounted) return;
    setState(() {
      _selectedSchool = school;
      _schoolSearchController.text = school.schoolName;
      _searchQuery = "";

      final List<String> newGrades = [];
      if (school.type == "초등학교") {
        newGrades.addAll(List.generate(6, (index) => (index + 1).toString()));
      } else if (school.type == "중학교" || school.type == "고등학교") {
        newGrades.addAll(List.generate(3, (index) => (index + 1).toString()));
      }
      newGrades.addAll(["졸업생", "기타학생"]);

      _availableGrades = newGrades;
      _selectedGrade = null;
    });
  }

  Future<void> _onSignUpPressed() async {
    if (!mounted) return;

    // 화면 단위 유효성 검사
    bool allValid = true;

    if (_selectedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학교를 선택해주세요.')),
      );
      allValid = false;
    }
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학년을 선택해주세요.')),
      );
      allValid = false;
    }
    if (!_isPrivacyPolicyAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('개인정보처리방침에 동의해주세요.')),
      );
      allValid = false;
    }

    if (!_formKey.currentState!.validate()) {
      allValid = false;
    }

    if (!allValid) return;

    // 회원가입 요청
    await ref.read(signUpControllerProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          nickname: _nicknameController.text.trim(),
          selectedSchool: _selectedSchool!,
          grade: _selectedGrade!,
        );
    // 성공/실패 처리는 ref.listen에서 처리
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(signUpControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회원가입 성공! 잠시 후 메인화면으로 이동합니다.')),
          );
          context.go('/splash');
        },
        error: (error, stackTrace) {
          if (!mounted) return;
          String errorMessage = "회원가입 중 오류가 발생했습니다.";
          if (error is String) {
            errorMessage = error;
          } else if (error is fb_auth.FirebaseAuthException) {
            errorMessage = mapAuthErrorCodeToMessage(error.code);
          } else if (error is Exception) {
            errorMessage = error.toString();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        },
      );
    });

    final schoolSearchResults = ref.watch(schoolSearchProvider(_searchQuery));
    final signUpLoading = ref.watch(signUpControllerProvider).isLoading;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background_signup.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(200),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '회원가입',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: '이메일 (아이디)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !value.contains('@')) {
                            return '유효한 이메일을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: '비밀번호',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              value.length < 6) {
                            return '6자 이상의 비밀번호를 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(
                          labelText: '닉네임',
                          border: OutlineInputBorder(),
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '닉네임을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _schoolSearchController,
                        decoration: InputDecoration(
                          labelText: '학교 검색',
                          hintText: '학교 이름을 2자 이상 입력하세요',
                          border: const OutlineInputBorder(),
                          suffixIcon: _schoolSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _schoolSearchController.clear();
                                    _onSearchChanged("");
                                    if (mounted) {
                                      setState(() {
                                        _selectedSchool = null;
                                        _availableGrades = [];
                                        _selectedGrade = null;
                                      });
                                    }
                                  },
                                )
                              : null,
                        ),
                        onChanged: _onSearchChanged,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (_) {
                          if (_selectedSchool == null) {
                            return '학교를 검색하여 선택해주세요.';
                          }
                          return null;
                        },
                      ),
                      if (_selectedSchool != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '선택된 학교: ${_selectedSchool!.schoolName} (${_selectedSchool!.type})',
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (_searchQuery.length >= 2 && _selectedSchool == null)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          margin: const EdgeInsets.only(top: 8.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(210),
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: schoolSearchResults.when(
                            data: (schools) {
                              if (schools.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Center(
                                    child: Text('검색 결과가 없습니다.'),
                                  ),
                                );
                              }
                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: schools.length,
                                itemBuilder: (context, index) {
                                  final school = schools[index];
                                  return ListTile(
                                    title: Text(school.schoolName),
                                    subtitle: Text(school.address),
                                    onTap: () => _updateAvailableGrades(school),
                                  );
                                },
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (err, _) => Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('학교 검색 오류: $err'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_selectedSchool != null &&
                          _availableGrades.isNotEmpty)
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                              'signup-grade-${_selectedSchool?.id ?? 'none'}'),
                          decoration: const InputDecoration(
                            labelText: '학년 선택',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: _selectedGrade,
                          hint: const Text('학년을 선택하세요'),
                          items: _availableGrades.map((gradeValue) {
                            final displayText = int.tryParse(gradeValue) != null
                                ? '$gradeValue 학년'
                                : gradeValue;
                            return DropdownMenuItem(
                              value: gradeValue,
                              child: Text(displayText),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (!mounted) return;
                            setState(() {
                              _selectedGrade = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return '학년을 선택해주세요.';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                      const SizedBox(height: 12),
                      FormField<bool>(
                        builder: (FormFieldState<bool> field) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                title: const Text(
                                  "개인정보처리방침에 동의합니다.",
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: _isPrivacyPolicyAgreed,
                                onChanged: (bool? value) {
                                  if (!mounted) return;
                                  setState(() {
                                    _isPrivacyPolicyAgreed = value ?? false;
                                    field.didChange(_isPrivacyPolicyAgreed);
                                  });
                                },
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                subtitle: field.hasError
                                    ? Text(
                                        field.errorText!,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          );
                        },
                        validator: (_) {
                          if (!_isPrivacyPolicyAgreed) {
                            return '개인정보처리방침에 동의해야 합니다.';
                          }
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        onPressed: signUpLoading ? null : _onSignUpPressed,
                        child: signUpLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('회원가입'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          if (!mounted) return;
                          context.go('/login');
                        },
                        child: const Text('이미 계정이 있으신가요? 로그인'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String mapAuthErrorCodeToMessage(String errorCode) {
  switch (errorCode) {
    case 'email-already-in-use':
      return '이미 사용 중인 이메일입니다.';
    case 'weak-password':
      return '비밀번호가 너무 약합니다. (6자 이상)';
    case 'invalid-email':
      return '유효하지 않은 이메일 형식입니다.';
    case 'operation-not-allowed':
      return '이메일/비밀번호 방식의 로그인이 활성화되어 있지 않습니다.';
    default:
      return '알 수 없는 오류가 발생했습니다. ($errorCode)';
  }
}
