import 'dart:async';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityToggleNotifier extends Notifier<bool> {
  static const String _key = 'security_enabled';

  @override
  bool build() {
    // 앱 시작 시 SharedPreferences에서 설정을 비동기적으로 불러오기 어렵기 때문에 
    // 기본값 true를 반환하고 build 내부에서 별도 초기화 로직을 수행하거나 
    // 그냥 동기적으로 불러오는 방법을 고려 (여기서는 초기화 메서드 호출)
    _loadState();
    return true; 
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

// 앱 재시작 시에도 유지되는 영속적 보안 설정
final securityToggleProvider = NotifierProvider<SecurityToggleNotifier, bool>(() {
  return SecurityToggleNotifier();
});

final securityServiceProvider = Provider((ref) => SecurityService());

class SecurityService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// 기기가 생체 인식을 지원하는지 확인
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      print('Biometric availability error: $e');
      return false;
    }
  }

  /// 생체 인식 또는 기기 비밀번호로 인증 실행
  Future<bool> authenticate({
    String reason = '기프티콘 확인을 위해 인증이 필요합니다.',
  }) async {
    try {
      // 해당 버전의 가장 기본 시그니처만 사용
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        // biometricOnly: false, // 이 매개변수도 에러가 난다면 제거 가능
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }
}
