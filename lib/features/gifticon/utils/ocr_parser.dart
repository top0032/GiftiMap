class OcrParser {
  /// 텍스트 블록에서 주요 정보를 추출하는 메인 함수
  static Map<String, String?> parseText(String rawText) {
    return {
      'expirationDate': extractExpirationDate(rawText),
      'barcodeNumber': extractBarcodeNumber(rawText),
      'brandName': extractBrandName(rawText),
      'productName': extractProductName(rawText),
    };
  }

  /// 잘 알려진 브랜드 키워드를 기반으로 브랜드명 추출
  static String? extractBrandName(String text) {
    final brands = [
      // 카페
      '스타벅스', '투썸플레이스', '이디야', '메가커피', '컴포즈커피', '빽다방', '할리스', '파스쿠찌',
      '커피빈', '공차', '폴바셋', '아티제', '텐퍼센트', '매머드커피', '블루보틀', '하삼동커피', '감성커피', '카페봄봄', '더벤티', '엔제리너스', '탐앤탐스',
      '더리터', '쥬씨', '백미당', '마호가니', '바나프레소', '만랩커피', '커피베이', '드롭탑', '카페베네', '고디바', '오설록', '더앨리', '달콤커피',
      // 베이커리 / 디저트
      '파리바게뜨', '파리바게트', '뚜레쥬르', '배스킨라빈스', '베스킨라빈스', '던킨', '설빙', '노티드', '크리스피크림', '홍루이젠', '명랑핫도그',
      '신라명과', '성심당', '이성당', '옵스', '파리크라상', '앤티앤스', '와플대학', '나뚜루', '하겐다즈',
      // 영화관 / 서점
      'CGV', '롯데시네마', '메가박스', '교보문고', '영풍문고', '예스24', '알라딘',
      // 편의점 / 마트
      'GS25', 'CU', '세븐일레븐', '이마트24', '미니스톱', '홈플러스', '이마트', '롯데마트',
      // 치킨
      '교촌치킨', 'BHC', 'BBQ', '굽네치킨', '푸라닭', '네네치킨', '처갓집', '60계치킨', '호식이두마리', '페리카나', '노랑통닭', '지코바', '바른치킨', '자담치킨',
      '또래오래', '멕시카나', '티바두마리치킨', '땅땅치킨', '디디치킨', '순수치킨',
      // 피자 / 패스트푸드 / 분식
      '맥도날드', '버거킹', 'KFC', '롯데리아', '맘스터치', '서브웨이', '써브웨이', '쉐이크쉑', '에그드랍', '이삭토스트',
      '도미노피자', '피자헛', '미스터피자', '파파존스', '피자알볼로', '반올림피자', '피자스쿨', '피자마루', '59쌀피자', '청년피자',
      '죠스떡볶이', '신전떡볶이', '엽기떡볶이', '배떡', '감탄떡볶이', '홍콩반점', '고봉민김밥', '봉구스밥버거',
      // 외식 / 레스토랑
      '아웃백', 'VIPS', '빕스', '애슐리', '매드포갈릭', '서가앤쿡', '본죽', '원할머니보쌈', '놀부부대찌개',
      // 생활 / 뷰티 / 쇼핑 / 기타
      '올리브영', '다이소', '신세계', '롯데백화점', '현대백화점', '배달의민족', '요기요', '쿠팡', '컬리', '카카오톡', '기프티콘',
      '이니스프리', '더페이스샵', '에뛰드', '구글플레이', '앱스토어', '넥슨', '스팀'
    ];
    
    // 텍스트에 브랜드 키워드가 포함되어 있는지 확인
    for (final brand in brands) {
      // 소문자로 변환하여 비교 (영어 브랜드명 대비)
      if (text.toUpperCase().contains(brand.toUpperCase())) {
        return brand;
      }
    }
    return null;
  }

  /// 많이 쓰이는 상품명 키워드가 포함된 줄을 찾아 상품명으로 추출
  static String? extractProductName(String text) {
    final lines = text.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      if (line.length < 2 || line.length > 25) continue; // 일반적인 상품명 길이
      
      final keywords = [
        // 범용 / 상품권 류 / 모바일 바우처
        '금액권', '교환권', '상품권', '이용권', '예매권', '기프트카드', '세트', '콤보', '모바일상품권', '문화상품권', '해피머니',
        '1만원권', '2만원권', '3만원권', '5만원권', '10만원권',
        
        // 커피 / 음료
        '아메리카노', '라떼', '프라푸치노', '콜드브루', '블렌디드', '스무디', '마끼아또', '모카', '에이드', '티', '밀크티',
        '아이스', '디카페인', '돌체', '바닐라', '헤이즐넛', '아샷추', '카라멜', '시럽', '프라페', '주스', '생과일', '아포가토', '플랫화이트', '오트', '두유',
        '캐모마일', '얼그레이', '녹차', '말차', '자몽', '레몬', '유자', '복숭아', '아이스티',
        
        // 치킨 / 피자 / 패스트푸드 / 분식
        '치킨', '피자', '버거', '치즈볼', '감자튀김', '포테이토', '프렌치프라이', '너겟', '텐더', '치즈스틱', '해쉬브라운', '코울슬로',
        '와퍼', '빅맥', '싸이버거', '불고기버거', '새우버거', '치즈버거', '치킨버거', '데리버거', '상하이버거', '징거버거', '타워버거',
        '뿌링클', '황금올리브', '고추바사삭', '허니콤보', '레드콤보', '블랙알리오', '고추마요',
        '떡볶이', '순대', '튀김', '핫도그', '만두', '김밥', '라면', '우동', '덮밥', '돈까스',
        
        // 베이커리 / 디저트 / 아이스크림
        '케이크', '마카롱', '도넛', '샌드위치', '토스트', '샐러드', '빙수', '크로플', '와플',
        '식빵', '바게트', '롤케익', '타르트', '마들렌', '스콘', '휘낭시에', '브라우니', '쿠키', '파운드',
        '아이스크림', '파인트', '쿼터', '하프갤런', '패밀리',
        
        // 영화관 / 스낵 / 음료수
        '팝콘', '나쵸', '콜라', '사이다'
      ];
      
      for (final keyword in keywords) {
        if (line.contains(keyword)) {
          // '상품명', '교환처' 같은 불필요한 접두사가 붙어있으면 제거
          line = line.replaceAll('상품명', '').replaceAll(':', '').trim();
          return line;
        }
      }
    }
    return null;
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
