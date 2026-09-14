class SmartAccessModel {
  final int bookingId;
  final String unitCode;
  final String accessPin;
  final String qrCodeToken;
  final String pinUpdatedAt;
  final String tokenExpiresAt;

  SmartAccessModel({
    required this.bookingId,
    required this.unitCode,
    required this.accessPin,
    required this.qrCodeToken,
    required this.pinUpdatedAt,
    required this.tokenExpiresAt,
  });

  factory SmartAccessModel.fromJson(Map<String, dynamic> json) {
    return SmartAccessModel(
      bookingId: json['bookingId'] ?? 0,
      unitCode: json['unitCode'] ?? '',
      accessPin: json['accessPin'] ?? '',
      qrCodeToken: json['qrCodeToken'] ?? '',
      pinUpdatedAt: json['pinUpdatedAt'] ?? '',
      tokenExpiresAt: json['tokenExpiresAt'] ?? '',
    );
  }
}
