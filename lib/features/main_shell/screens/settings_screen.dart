// lib/features/main_shell/screens/settings_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ranking_ground_v1/data/models/school_model.dart';
import 'package:ranking_ground_v1/data/models/user_model.dart';
import 'package:ranking_ground_v1/features/auth/providers/auth_provider.dart';
import 'package:ranking_ground_v1/features/main_shell/providers/notice_provider.dart';
import 'package:ranking_ground_v1/features/main_shell/widgets/notice_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolSearchController = TextEditingController();
  Timer? _schoolSearchDebounce;

  SchoolModel? _selectedSchool;
  String? _selectedGrade;
  String _schoolSearchQuery = '';
  bool _isModified = false;
  bool _isInitialDataLoaded = false;

  @override
  void dispose() {
    _schoolSearchDebounce?.cancel();
    _schoolSearchController.dispose();
    super.dispose();
  }

  void _initializeForm(UserModel user, SchoolModel? school) {
    if (!_isInitialDataLoaded) {
      _selectedSchool = school;
      _schoolSearchController.text = school?.schoolName ?? '';
      _schoolSearchQuery = '';
      _selectedGrade = user.grade;
      _isInitialDataLoaded = true;
    }
  }

  void _onSchoolSearchChanged(UserModel user, String input) {
    _schoolSearchDebounce?.cancel();
    _schoolSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final query = input.trim();
      final selectedSchoolName = _selectedSchool?.schoolName ?? '';

      setState(() {
        _schoolSearchQuery = query;
        if (query != selectedSchoolName) {
          _selectedSchool = null;
          _selectedGrade = null;
        }
      });
      _checkForModifications(user);
    });
  }

  void _checkForModifications(UserModel originalUser) {
    final schoolChanged = _selectedSchool?.id != originalUser.schoolId;
    final gradeChanged = _selectedGrade != originalUser.grade;
    _isModified = schoolChanged || gradeChanged;
  }

  Future<void> _submit(UserModel currentUser) async {
    if (_formKey.currentState!.validate() && _isModified) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final success =
          await ref.read(editProfileControllerProvider.notifier).updateProfile(
                uid: currentUser.uid,
                school: _selectedSchool,
                grade: _selectedGrade,
              );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '정보가 성공적으로 수정되었습니다.' : '정보 수정 중 오류가 발생했습니다.',
            ),
          ),
        );
        if (success) {
          setState(() {
            _isModified = false;
            _isInitialDataLoaded = false;
          });
          ref.invalidate(userProfileProvider);
          ref.invalidate(schoolDetailsProvider(currentUser.schoolId));
        }
      }
    }
  }

  Future<void> _logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
  }

  Future<void> _createDebugNotice() async {
    try {
      final noticeService = ref.read(noticeServiceProvider);
      final version = await noticeService.createDebugSampleNotice();
      await noticeService.resetDebugDoNotShowToday();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('디버그 공지 생성 완료 (version: $version)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('디버그 공지 생성 실패: $e')),
      );
    }
  }

  Future<void> _resetNoticeSuppression() async {
    try {
      await ref.read(noticeServiceProvider).resetDoNotShowToday();
      await ref.read(noticeServiceProvider).resetDebugDoNotShowToday();
      ref.invalidate(noticeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공지 숨김 상태를 초기화했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 실패: $e')),
      );
    }
  }

  Future<void> _previewNoticeDialog() async {
    try {
      final notice =
          await ref.read(noticeServiceProvider).fetchLatestDebugNotice();
      if (!mounted) return;
      if (notice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('표시 가능한 디버그 공지가 없습니다.')),
        );
        return;
      }
      await showNoticeDialog(
        context: context,
        notice: notice,
        onDoNotShowToday: () => ref
            .read(noticeServiceProvider)
            .setDoNotShowTodayForDebug(notice.version),
        barrierDismissible: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공지 미리보기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: userProfileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
          }

          bool canEdit = true;
          String nextEditDateStr = '';
          if (user.profileLastUpdatedAt != null) {
            final lastEditDate = user.profileLastUpdatedAt!.toDate();
            final nextEditDate = DateTime(
                lastEditDate.year, lastEditDate.month + 6, lastEditDate.day);
            if (DateTime.now().isBefore(nextEditDate)) {
              canEdit = false;
              nextEditDateStr =
                  DateFormat('yyyy년 MM월 dd일').format(nextEditDate);
            }
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: const Text('설정'),
              actions: [
                if (_isModified && canEdit)
                  TextButton(
                    onPressed: () => _submit(user),
                    child: const Text('저장'),
                  )
              ],
            ),
            body: ref.watch(schoolDetailsProvider(user.schoolId)).when(
                  data: (school) {
                    _initializeForm(user, school);
                    return Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 24.0),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: _buildUserInfoSummary(user, school),
                          ),
                          _buildSectionTitle('내 정보 관리'),
                          const SizedBox(height: 12),
                          _buildSchoolSearch(user, canEdit),
                          const SizedBox(height: 16),
                          _buildGradeDropdown(user, canEdit),
                          if (!canEdit)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Text(
                                '프로필 정보는 6개월에 한 번만 수정할 수 있습니다.\n다음 수정 가능일: $nextEditDateStr',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          _buildSectionTitle('계정'),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.logout),
                            title: const Text('로그아웃'),
                            onTap: _logout,
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildSectionTitle('디버그 - 공지 점검'),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: _createDebugNotice,
                              icon: const Icon(Icons.add_alert_outlined),
                              label: const Text('테스트 공지 생성'),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: _resetNoticeSuppression,
                              icon: const Icon(Icons.refresh),
                              label: const Text('숨김 상태 초기화'),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: _previewNoticeDialog,
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('공지 팝업 미리보기'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('학교 정보를 불러오는 중 오류: $e')),
                ),
          );
        },
        loading: () => Scaffold(
            appBar: AppBar(title: const Text('설정')),
            body: const Center(child: CircularProgressIndicator())),
        error: (e, st) => Scaffold(
            appBar: AppBar(title: const Text('설정')),
            body: Center(child: Text('사용자 정보를 불러오는 중 오류: $e'))),
      ),
    );
  }

  Widget _buildUserInfoSummary(UserModel user, SchoolModel? school) {
    final formatter = NumberFormat('#,###');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(
                icon: '🏫',
                label: '소속학교',
                value: school?.schoolName ?? '정보 없음'),
            const SizedBox(height: 8),
            _buildSummaryRow(icon: '🎓', label: '학년', value: user.grade),
            const SizedBox(height: 8),
            _buildSummaryRow(
              icon: '📊',
              label: '누적 점수',
              value: '${formatter.format(user.score_total_personal)}점',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
      {required String icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Text('$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSchoolSearch(UserModel user, bool isEditable) {
    final searchResults = ref.watch(schoolSearchProvider(_schoolSearchQuery));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          enabled: isEditable,
          controller: _schoolSearchController,
          decoration: const InputDecoration(
            labelText: '학교 변경',
            suffixIcon: Icon(Icons.edit_outlined),
          ),
          onChanged: (value) => _onSchoolSearchChanged(user, value),
          validator: (_) => _selectedSchool == null ? '학교를 선택해주세요.' : null,
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            '획득한 점수는 소속 학교의 랭킹에 반영됩니다. 우리 학교의 명예를 드높여주세요!',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        if (isEditable && _schoolSearchQuery.length >= 2)
          searchResults.when(
            data: (schools) => Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                itemCount: schools.length,
                itemBuilder: (_, index) {
                  final sch = schools[index];
                  return ListTile(
                    title: Text(sch.schoolName),
                    subtitle: Text(sch.address),
                    onTap: () {
                      setState(() {
                        _selectedSchool = sch;
                        _schoolSearchController.clear();
                        _schoolSearchController.text = sch.schoolName;
                        _schoolSearchQuery = '';
                        _selectedGrade = null;
                        _checkForModifications(user);
                      });
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('오류: $e'),
          ),
      ],
    );
  }

  Widget _buildGradeDropdown(UserModel user, bool isEditable) {
    List<String> grades = [];
    final schoolType = _selectedSchool?.type;

    if (schoolType == '초등학교') {
      grades = ['1학년', '2학년', '3학년', '4학년', '5학년', '6학년', '졸업생', '기타학생'];
    } else if (schoolType == '중학교' || schoolType == '고등학교') {
      grades = ['1학년', '2학년', '3학년', '졸업생', '기타학생'];
    }

    return DropdownButtonFormField<String>(
      key: ValueKey('settings-grade-${_selectedSchool?.id ?? 'none'}'),
      initialValue: _selectedGrade,
      items: grades
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: isEditable
          ? (value) {
              setState(() {
                _selectedGrade = value;
                _checkForModifications(user);
              });
            }
          : null,
      decoration: const InputDecoration(
        labelText: '학년 변경',
        suffixIcon: Icon(Icons.edit_outlined),
      ),
      validator: (value) =>
          value == null && grades.isNotEmpty ? '학년을 선택해주세요.' : null,
      hint: Text(isEditable ? '학교를 먼저 선택해주세요' : '수정 불가'),
    );
  }
}
