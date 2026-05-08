class BrandInfo {
  final String name;
  final String logoAsset;
  final String category;

  BrandInfo({
    required this.name,
    required this.logoAsset,
    required this.category,
  });
}

/// 브랜드명과 로고, 카테고리를 매핑하는 테이블
final Map<String, BrandInfo> brandMap = {
  // 카페
  '스타벅스': BrandInfo(name: '스타벅스', logoAsset: 'assets/logos/starbucks.png', category: '카페'),
  '투썸플레이스': BrandInfo(name: '투썸플레이스', logoAsset: 'assets/logos/twosome.png', category: '카페'),
  '이디야': BrandInfo(name: '이디야', logoAsset: 'assets/logos/ediya.png', category: '카페'),
  '메가커피': BrandInfo(name: '메가커피', logoAsset: 'assets/logos/mega.png', category: '카페'),
  '컴포즈커피': BrandInfo(name: '컴포즈커피', logoAsset: 'assets/logos/compose.png', category: '카페'),
  '빽다방': BrandInfo(name: '빽다방', logoAsset: 'assets/logos/paik.png', category: '카페'),
  '할리스': BrandInfo(name: '할리스', logoAsset: 'assets/logos/hollys.png', category: '카페'),
  
  // 편의점
  'GS25': BrandInfo(name: 'GS25', logoAsset: 'assets/logos/gs25.png', category: '편의점'),
  'CU': BrandInfo(name: 'CU', logoAsset: 'assets/logos/cu.png', category: '편의점'),
  '세븐일레븐': BrandInfo(name: '세븐일레븐', logoAsset: 'assets/logos/seven.png', category: '편의점'),
  '이마트24': BrandInfo(name: '이마트24', logoAsset: 'assets/logos/emart24.png', category: '편의점'),
  
  // 패스트푸드 / 치킨
  '맥도날드': BrandInfo(name: '맥도날드', logoAsset: 'assets/logos/mcdonalds.png', category: '패스트푸드'),
  '버거킹': BrandInfo(name: '버거킹', logoAsset: 'assets/logos/burgerking.png', category: '패스트푸드'),
  '교촌치킨': BrandInfo(name: '교촌치킨', logoAsset: 'assets/logos/kyochon.png', category: '치킨'),
  'BHC': BrandInfo(name: 'BHC', logoAsset: 'assets/logos/bhc.png', category: '치킨'),
  'BBQ': BrandInfo(name: 'BBQ', logoAsset: 'assets/logos/bbq.png', category: '치킨'),
  
  // 베이커리
  '파리바게뜨': BrandInfo(name: '파리바게뜨', logoAsset: 'assets/logos/paris.png', category: '베이커리'),
  '뚜레쥬르': BrandInfo(name: '뚜레쥬르', logoAsset: 'assets/logos/tous.png', category: '베이커리'),
  '배스킨라빈스': BrandInfo(name: '배스킨라빈스', logoAsset: 'assets/logos/baskin.png', category: '디저트'),
  '던킨': BrandInfo(name: '던킨', logoAsset: 'assets/logos/dunkin.png', category: '디저트'),
};
