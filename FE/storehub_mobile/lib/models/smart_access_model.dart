class SmartAccessModel {
  final String bookingId;
  final String unitCode;
  final String accessPin;
  final String qrCodeToken;
  final DateTime? pinUpdatedAt;
  final DateTime? tokenExpiresAt;

  SmartAccessModel({
    required this.bookingId,
    required this.unitCode,
    required this.accessPin,
    required this.qrCodeToken,
    this.pinUpdatedAt,
    this.tokenExpiresAt,
  });

  factory SmartAccessModel.fromJson(Map<String, dynamic> json) {
    return SmartAccessModel(
      bookingId: json['bookingId']?.toString() ?? '',
      unitCode: json['unitCode']?.toString() ?? '',
      accessPin: json['accessPin']?.toString() ?? '',
      qrCodeToken: json['qrCodeToken']?.toString() ?? '',
      pinUpdatedAt: json['pinUpdatedAt'] != null
          ? DateTime.tryParse(json['pinUpdatedAt'].toString())
          : null,
      tokenExpiresAt: json['tokenExpiresAt'] != null
          ? DateTime.tryParse(json['tokenExpiresAt'].toString())
          : null,
    );
  }
}
