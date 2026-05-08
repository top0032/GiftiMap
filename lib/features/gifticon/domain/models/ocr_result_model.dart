class OcrResultModel {
  final String rawText;
  final String? brandName;
  final String? productName;
  final String? expirationDate;
  final String? barcodeNumber;
  final String? category;
  final String? logoPath;
  final String? imagePath;

  OcrResultModel({
    required this.rawText,
    this.brandName,
    this.productName,
    this.expirationDate,
    this.barcodeNumber,
    this.category,
    this.logoPath,
    this.imagePath,
  });

  OcrResultModel copyWith({
    String? rawText,
    String? brandName,
    String? productName,
    String? expirationDate,
    String? barcodeNumber,
    String? category,
    String? logoPath,
    String? imagePath,
  }) {
    return OcrResultModel(
      rawText: rawText ?? this.rawText,
      brandName: brandName ?? this.brandName,
      productName: productName ?? this.productName,
      expirationDate: expirationDate ?? this.expirationDate,
      barcodeNumber: barcodeNumber ?? this.barcodeNumber,
      category: category ?? this.category,
      logoPath: logoPath ?? this.logoPath,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  @override
  String toString() {
    return 'OcrResultModel(brandName: $brandName, productName: $productName, expirationDate: $expirationDate, barcodeNumber: $barcodeNumber, imagePath: $imagePath)';
  }
}
