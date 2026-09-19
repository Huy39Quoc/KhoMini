// Matches BE SmartAccessResponse: { bookingId, unitCode, accessPin,
// qrCodeToken, pinUpdatedAt, tokenExpiresAt }
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
      // No fake fallback PIN: an empty string means "not available", and
      // the UI shows that honestly instead of a made-up default.
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
