import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class MapLauncher {
  /// 외부 지도 앱으로 길찾기를 실행합니다.
  static Future<void> launchRoute({
    required double lat,
    required double lng,
    required String name,
  }) async {
    final String encodedName = Uri.encodeComponent(name);

    // 1. 카카오맵 (kakaomap://)
    final Uri kakaoUrl = Uri.parse('kakaomap://route?ep=$lat,$lng&by=FOOT');
    
    // 2. 네이버 지도 (nmap://)
    final Uri naverUrl = Uri.parse('nmap://route/walk?dlat=$lat&dlng=$lng&dname=$encodedName&appname=com.minsu.giftimap');
    
    // 3. 구글 맵 (https://) - iOS/Android 공통
    final Uri googleUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');

    if (Platform.isAndroid) {
      if (await canLaunchUrl(kakaoUrl)) {
        await launchUrl(kakaoUrl);
      } else if (await canLaunchUrl(naverUrl)) {
        await launchUrl(naverUrl);
      } else {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      }
    } else if (Platform.isIOS) {
      if (await canLaunchUrl(kakaoUrl)) {
        await launchUrl(kakaoUrl);
      } else if (await canLaunchUrl(naverUrl)) {
        await launchUrl(naverUrl);
      } else {
        await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      }
    } else {
      // 웹이나 다른 플랫폼
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// 사용자가 선택할 수 있도록 개별 앱 실행 메서드 제공
  static Future<void> launchKakaoMap(double lat, double lng) async {
    final Uri url = Uri.parse('kakaomap://route?ep=$lat,$lng&by=FOOT');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw '카카오맵을 실행할 수 없습니다.';
    }
  }

  static Future<void> launchNaverMap(double lat, double lng, String name) async {
    final String encodedName = Uri.encodeComponent(name);
    final Uri url = Uri.parse('nmap://route/walk?dlat=$lat&dlng=$lng&dname=$encodedName&appname=com.minsu.giftimap');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw '네이버 지도를 실행할 수 없습니다.';
    }
  }

  static Future<void> launchGoogleMap(double lat, double lng) async {
    final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
