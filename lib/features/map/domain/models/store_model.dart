class StoreModel {
  final String id;
  final String placeName;     // 매장명 (예: 스타벅스 강남역점)
  final String addressName;   // 지번 주소
  final String roadAddressName; // 도로명 주소
  final double latitude;      // y좌표 (위도)
  final double longitude;     // x좌표 (경도)
  final double distance;      // 내 위치와의 거리 (미터 단위)
  final String phone;         // 전화번호
  final String matchedBrand;  // 어떤 기프티콘 브랜드와 매칭되었는지 (예: '스타벅스')

  StoreModel({
    required this.id,
    required this.placeName,
    required this.addressName,
    required this.roadAddressName,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.phone,
    required this.matchedBrand,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json, String matchedBrand) {
    return StoreModel(
      id: json['id'] as String,
      placeName: json['place_name'] as String,
      addressName: json['address_name'] as String,
      roadAddressName: json['road_address_name'] as String,
      latitude: double.parse(json['y'] as String),
      longitude: double.parse(json['x'] as String),
      distance: double.parse(json['distance'] as String),
      phone: json['phone'] as String,
      matchedBrand: matchedBrand,
    );
  }
}
