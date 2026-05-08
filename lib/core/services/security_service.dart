import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
