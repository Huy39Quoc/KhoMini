class SmartAccessModel {
  final String bookingId;
  final String unitCode;
  final String accessPin;
  final String qrCodeToken;
  final String pinUpdatedAt;

  SmartAccessModel({
    required this.bookingId,
    required this.unitCode,
    required this.accessPin,
    required this.qrCodeToken,
    required this.pinUpdatedAt,
  });

  factory SmartAccessModel.fromJson(Map<String, dynamic> json) {
    return SmartAccessModel(
      bookingId: json['bookingId']?.toString() ?? '',
      unitCode: json['unitCode'] ?? '',
      accessPin: json['accessPin'] ?? '123456',
      qrCodeToken: json['qrCodeToken'] ?? '',
      pinUpdatedAt: json['pinUpdatedAt'] ?? '',
    );
  }
}
