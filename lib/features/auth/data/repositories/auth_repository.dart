import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:flutter/services.dart';

/// 인증 관련 데이터 처리를 담당하는 저장소(Repository) 클래스입니다.
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '999471022250-vukep0886fvkvptlrjqb8vkgambhddup.apps.googleusercontent.com',
  );

  /// 현재 로그인된 사용자(User) 정보를 반환합니다.
  User? get currentUser => _auth.currentUser;

  /// 사용자 인증 상태(Authentication State)의 변화를 감지하는 스트림(Stream)입니다.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 구글 계정을 이용해 로그인을 진행합니다.
  /// 
  /// 사용자가 로그인을 취소하면 `null`을 반환합니다.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 구글 로그인 UI 표시 및 계정 선택
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // 사용자가 로그인을 취소함
      }

      // 선택된 계정으로부터 인증 정보(Authentication Tokens) 획득
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase 인증에 사용할 자격 증명(Credential) 생성
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 자격 증명을 전달하여 로그인 완료
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      // 에러 발생 시 로그 출력 후 예외 재발생
      print('구글 로그인 중 오류 발생: $e');
      rethrow;
    }
  }

  /// 카카오 로그인을 수행하고 Firebase 익명 사용자와 연동합니다.
  Future<Map<String, dynamic>?> signInWithKakao() async {
    try {
      print('[KAKAO_LOGIN] Step 1: Checking if KakaoTalk is installed...');
      if (await kakao.isKakaoTalkInstalled()) {
        print('[KAKAO_LOGIN] Step 2: KakaoTalk installed. Attempting Talk Login...');
        try {
          await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          if (error is PlatformException && error.code == 'CANCELED') return null;
          await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 1. 카카오 사용자 정보 먼저 가져오기
      final kakaoUser = await kakao.UserApi.instance.me();
      final nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? '사용자';
      final photoUrl = kakaoUser.kakaoAccount?.profile?.thumbnailImageUrl;
      
      // 2. 카카오 ID 기반 가상 이메일/비밀번호 생성
      final String kakaoId = kakaoUser.id.toString();
      final String email = 'k$kakaoId@gmail.com'; // 도메인을 gmail로 변경 테스트
      final String password = 'Kakao$kakaoId!@#'; 
      
      UserCredential? userCredential;
      
      try {
        await _auth.signOut();
        print('[KAKAO_LOGIN] Step 3: Attempting login for $email');
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email, 
          password: password,
        );
      } catch (e) {
        print('[KAKAO_LOGIN] Step 4: Login failed ($e). Attempting to create account.');
        try {
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: email, 
            password: password,
          );
        } catch (e2) {
          print('[KAKAO_LOGIN] Step 5: Create failed ($e2). Final attempt login.');
          try {
            userCredential = await _auth.signInWithEmailAndPassword(
              email: email, 
              password: password,
            );
          } catch (e3) {
            print('[KAKAO_LOGIN] [CRITICAL_ERROR] Final attempt also failed: $e3');
            rethrow;
          }
        }
      }
      
      final firebaseUser = userCredential?.user;
      
      if (firebaseUser != null) {
        try {
          // 카카오 프로필 정보로 Firebase 유저 정보 업데이트
          await firebaseUser.updateDisplayName(nickname);
          if (photoUrl != null) {
            await firebaseUser.updatePhotoURL(photoUrl);
          }
          
          // 변경사항 반영을 위해 리로드
          await firebaseUser.reload();
          final updatedUser = _auth.currentUser;
          
          // ID 토큰 강제 갱신으로 상태 변경 알림 유도
          await updatedUser?.getIdToken(true);
          
          print('[KAKAO_LOGIN] Success: User updated with nickname: $nickname');
          
          return {
            'user': updatedUser,
            'nickname': nickname,
          };
        } catch (e) {
          print('[KAKAO_LOGIN] Profile update error: $e');
          return {
            'user': firebaseUser,
            'nickname': nickname,
          };
        }
      }
      return null;
    } catch (e) {
      print('[KAKAO_LOGIN] [ERROR] $e');
      rethrow;
    }
  }

  /// 로그아웃(Sign Out)을 수행합니다.
  /// 
  /// 모든 소셜 로그인 세션과 Firebase 로그인 세션을 모두 해제합니다.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      try {
        await kakao.UserApi.instance.logout();
      } catch (_) {}
      await _auth.signOut();
    } catch (e) {
      print('로그아웃 중 오류 발생: $e');
      rethrow;
    }
  }
}
