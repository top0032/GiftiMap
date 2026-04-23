import 'package:cloud_firestore/cloud_firestore.dart';

class GifticonModel {
  final String id;
  final String brandName;
  final String productName;
  final String expirationDate;
  final String barcodeNumber;
  final DateTime createdAt;

  GifticonModel({
    required this.id,
    required this.brandName,
    required this.productName,
    required this.expirationDate,
    required this.barcodeNumber,
    required this.createdAt,
  });

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
    };
  }
}
