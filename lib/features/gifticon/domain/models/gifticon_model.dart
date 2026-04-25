import 'package:cloud_firestore/cloud_firestore.dart';

class GifticonModel {
  final String id;
  final String brandName;
  final String productName;
  final String expirationDate;
  final String barcodeNumber;
  final DateTime createdAt;
  final String? imageUrl;
  final bool? isUsed;

  GifticonModel({
    required this.id,
    required this.brandName,
    required this.productName,
    required this.expirationDate,
    required this.barcodeNumber,
    required this.createdAt,
    this.imageUrl,
    this.isUsed = false,
  });

  GifticonModel copyWith({
    String? id,
    String? brandName,
    String? productName,
    String? expirationDate,
    String? barcodeNumber,
    DateTime? createdAt,
    String? imageUrl,
    bool? isUsed,
  }) {
    return GifticonModel(
      id: id ?? this.id,
      brandName: brandName ?? this.brandName,
      productName: productName ?? this.productName,
      expirationDate: expirationDate ?? this.expirationDate,
      barcodeNumber: barcodeNumber ?? this.barcodeNumber,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      isUsed: isUsed ?? this.isUsed,
    );
  }

  // Firestore 문서에서 모델 객체로 변환
  factory GifticonModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GifticonModel(
      id: doc.id,
      brandName: data['brandName'] ?? '브랜드 없음',
      productName: data['productName'] ?? '상품명 없음',
      expirationDate: data['expirationDate'] ?? '기한 없음',
      barcodeNumber: data['barcodeNumber'] ?? '바코드 없음',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'],
      isUsed: data['isUsed'] ?? false,
    );
  }

  // 모델 객체를 Firestore 문서 형식으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'brandName': brandName,
      'productName': productName,
      'expirationDate': expirationDate,
      'barcodeNumber': barcodeNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      if (imageUrl != null) 'imageUrl': imageUrl,
      'isUsed': isUsed == true,
    };
  }

  // 남은 기간 파싱 및 D-Day 계산 로직 추가
  int get remainingDays {
    try {
      // expirationDate 형식이 'YYYY.MM.DD', 'YYYY-MM-DD' 또는 'YYYY년 MM월 DD일' 등 다양할 수 있으므로 정제
      // [주의] 하이픈(-)이 캐릭터 클래스 중간에 있으면 범위를 뜻하게 되어 숫자까지 모두 매칭하는 버그 방지
      final regex = RegExp(r'(\d{4})[./년\s\-]*(\d{1,2})[./월\s\-]*(\d{1,2})');
      final match = regex.firstMatch(expirationDate);
      
      if (match != null && match.groupCount >= 3) {
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        
        final expDate = DateTime(year, month, day);
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        
        return expDate.difference(todayOnly).inDays;
      }
      return -999; // 날짜를 찾을 수 없음
    } catch (e) {
      return -999; // 날짜 파싱 실패
    }
  }

  String get dDayString {
    if (isUsed == true) return '사용완료';
    final days = remainingDays;
    if (days == -999) return 'D-?';
    if (days < 0) return '기간만료';
    if (days == 0) return 'D-Day';
    return 'D-$days';
  }
}
