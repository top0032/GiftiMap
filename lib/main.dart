import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme.dart';
import 'features/map/data/services/geofence_notification_service.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/gifticon/data/services/expiration_notification_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'features/map/data/services/geofence_task_handler.dart';
import 'core/services/background_callback.dart';

void main() async {
  print('--- App Starting... ---');
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 상단 상태바(시간, 배터리 등)가 하얀 배경에서 잘 보이도록 아이콘을 어둡게 설정
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // 투명 상태바
        statusBarIconBrightness: Brightness.dark, // 안드로이드 어두운 아이콘
        statusBarBrightness: Brightness.light, // iOS 어두운 아이콘
      ),
    );

    // 환경변수 로드
    await dotenv.load(fileName: ".env");
    print('.env loaded: ${dotenv.env.keys.take(3).toList()}');

    // 카카오 SDK 초기화 (로그인용: 네이티브 앱 키)
    final nativeKey = dotenv.env['KAKAO_NATIVE_APP_KEY'];
    // 카카오맵 초기화 (지도용: 자바스크립트 앱 키)
    final jsKey = dotenv.env['KAKAO_JS_APP_KEY'];

    if (nativeKey != null && nativeKey.isNotEmpty) {
      // 카카오 로그인 SDK 초기화 (네이티브 키 필수)
      kakao.KakaoSdk.init(nativeAppKey: nativeKey);
    }

    if (jsKey != null && jsKey.isNotEmpty) {
      // 카카오맵 초기화 (자바스크립트 키 권장)
      AuthRepository.initialize(
        appKey: jsKey, 
        baseUrl: 'http://localhost',
      );
    }
    
    // 알림 서비스 초기화 (지오펜싱 및 유효기간 임박 알림)
    tz.initializeTimeZones(); // 시간대 데이터 로드
    tz.setLocalLocation(tz.getLocation('Asia/Seoul')); // 현지 시간대 설정
    await GeofenceNotificationService().initialize();
    await ExpirationNotificationService().initialize();

    // Firebase 초기화 (중복 초기화 방지)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }

    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  } catch (e, stack) {
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                '두 번째 초기화 실패:\n\n$e\n\n$stack',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return WithForegroundTask(
      child: MaterialApp.router(
        title: 'GiftiMap',
        theme: AppTheme.lightTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'),
        ],
        locale: const Locale('ko', 'KR'),
      ),
    );
  }
}
