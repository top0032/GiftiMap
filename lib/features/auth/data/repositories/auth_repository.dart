import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  /// 로그아웃(Sign Out)을 수행합니다.
  /// 
  /// 구글 로그인 세션과 Firebase 로그인 세션을 모두 해제합니다.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('로그아웃 중 오류 발생: $e');
      rethrow;
    }
  }
}
