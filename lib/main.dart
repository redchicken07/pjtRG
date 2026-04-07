// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ranking_ground_v1/core/routes/app_router.dart'; // 수정: 프로젝트명 기반 경로
import 'firebase_options.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // 추가

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final supportsMobileAds = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (supportsMobileAds) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds initialize failed: $e');
    }
  }
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WidgetRef ref 추가
    final router = ref.watch(appRouterProvider); // appRouterProvider 사용

    return MaterialApp.router(
      routerConfig: router,
      title: '학교 대항 퀴즈 앱',
      // theme: AppTheme.lightTheme, // 필요시 테마 설정
      debugShowCheckedModeBanner: false,
    );
  }
}
