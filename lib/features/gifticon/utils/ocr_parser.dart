class OcrParser {
  /// 텍스트 블록에서 주요 정보를 추출하는 메인 함수
  static Map<String, String?> parseText(String rawText) {
    return {
      'expirationDate': extractExpirationDate(rawText),
      'barcodeNumber': extractBarcodeNumber(rawText),
      // 추가적인 파싱(브랜드, 상품명 등)은 기프티콘 종류에 따라 다양하게 발생할 수 있으므로
      // 필요에 따라 아래에 로직을 추가 구성합니다.
    };
  }

  /// 유효기간 형태 (YYYY.MM.DD 또는 YYYY년 MM월 DD일 등) 정규표현식 추출
  static String? extractExpirationDate(String text) {
    // 2024.12.31, 2024-12-31, 2024년 12월 31일 등 매칭
    final RegExp dateRegExp = RegExp(
      r'20\d{2}[\s\-./년]*\d{1,2}[\s\-./월]*\d{1,2}일?',
    );

    final match = dateRegExp.firstMatch(text);
    if (match != null) {
      // 추출된 문자열 다듬기
      String dateStr = match.group(0)!;
      // 필요한 경우 통일된 포맷(YYYY-MM-DD)으로 변환하는 로직 추가 가능
      return dateStr.trim();
    }
    return null;
  }

  /// 바코드 번호 (연속된 12자리 이상 숫자) 추출
  static String? extractBarcodeNumber(String text) {
    // 공백이나 하이픈을 포함하여 연속된 숫자를 찾는 정규식
    final RegExp barcodeRegExp = RegExp(r'\d{4}[\s\-]*\d{4}[\s\-]*\d{4}[\s\-]*\d{0,4}');
    
    // 전체 텍스트에서 매치되는 부분 찾기
    final matches = barcodeRegExp.allMatches(text);
    for (final match in matches) {
      String? matchedString = match.group(0);
      if (matchedString != null) {
        // 공백과 하이픈 제거
        String cleanNumber = matchedString.replaceAll(RegExp(r'[\s\-]'), '');
        // 12자리 이상인 경우만 리턴
        if (cleanNumber.length >= 12) {
          return cleanNumber;
        }
      }
    }
    return null;
  }
}
