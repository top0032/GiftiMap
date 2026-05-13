import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

/// 사용자에게 구글 로그인(Google Login)을 제공하는 화면입니다.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 로그인 컨트롤러의 상태(State)를 감시합니다.
    final authState = ref.watch(authControllerProvider);

    // 에러 발생 시 SnackBar로 표시합니다.
    ref.listen(authControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 실패: ${next.error}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        // 배경에 세련된 그라데이션(Gradient)을 적용합니다.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4E65FF), // 밝은 파란색
              Color(0xFF92EFFD), // 하늘색
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 앱 아이콘 형태의 디자인
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 앱 타이틀
                  const Text(
                    '기프티콘',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 앱 설명
                  const Text(
                    '똑똑하게 관리하고 알림 받는 기프티콘',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 80),

                  // 로그인 버튼 섹션
                  if (authState.isLoading)
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  else ...[
                    // Google 로그인 버튼
                    ElevatedButton(
                      onPressed: () {
                        ref.read(authControllerProvider.notifier).signInWithGoogle();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        minimumSize: const Size(double.infinity, 56), // 버튼 너비 확장
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black26,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.png',
                            height: 24,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.login,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Google로 로그인',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Kakao 로그인 버튼
                    ElevatedButton(
                      onPressed: () {
                        ref.read(authControllerProvider.notifier).signInWithKakao();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE500), // 카카오 시그니처 옐로우
                        foregroundColor: const Color(0xFF191919),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        minimumSize: const Size(double.infinity, 56), // 버튼 너비 확장
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black26,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_rounded, size: 24),
                          const SizedBox(width: 16),
                          Text(
                            '카카오로 로그인',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

