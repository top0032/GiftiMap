import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/store_model.dart';

class KakaoLocalApiService {
  final String _baseUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';

  Future<List<StoreModel>> searchNearbyStores({
    required String brandName,
    required double latitude,
    required double longitude,
    int radius = 1000, // 기본 1km 반경
  }) async {
    final restApiKey = dotenv.env['KAKAO_REST_API_KEY'];
    if (restApiKey == null || restApiKey.isEmpty) {
      throw Exception('.env 파일에 KAKAO_REST_API_KEY가 설정되지 않았습니다.');
    }

    final uri = Uri.parse(
        '$_baseUrl?query=$brandName&y=$latitude&x=$longitude&radius=$radius&sort=distance');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'KakaoAK $restApiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final documents = data['documents'] as List;

        return documents
            .map((doc) => StoreModel.fromJson(doc, brandName))
            .toList();
      } else {
        print('Kakao API Error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Kakao API Exception: $e');
      return [];
    }
  }
}
