class OcrResultModel {
  final String rawText;
  final String? brandName;
  final String? productName;
  final String? expirationDate;
  final String? barcodeNumber;

  OcrResultModel({
    required this.rawText,
    this.brandName,
    this.productName,
    this.expirationDate,
    this.barcodeNumber,
  });

  @override
  String toString() {
    return 'OcrResultModel(rawText length: ${rawText.length}, brandName: $brandName, productName: $productName, expirationDate: $expirationDate, barcodeNumber: $barcodeNumber)';
  }
}
