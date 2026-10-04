// Matches BE SmartAccessResponse: { bookingId, unitCode, pinSet, pinUpdatedAt,
// locked, attemptsRemaining, pinLockedUntil, generatedPin }
//
// Server chỉ lưu PIN dạng băm nên KHÔNG bao giờ gửi lại PIN đã lưu.
// generatedPin chỉ có giá trị đúng một lần, ngay sau khi hệ thống tạo PIN mới.
class SmartAccessModel {
  final String bookingId;
  final String unitCode;
  final bool pinSet;
  final DateTime? pinUpdatedAt;
  final bool locked;
  final int attemptsRemaining;
  final DateTime? pinLockedUntil;
  final String? generatedPin;

  SmartAccessModel({
    required this.bookingId,
    required this.unitCode,
    this.pinSet = false,
    this.pinUpdatedAt,
    this.locked = true,
    this.attemptsRemaining = 5,
    this.pinLockedUntil,
    this.generatedPin,
  });

  bool get isTemporarilyBlocked =>
      pinLockedUntil != null && pinLockedUntil!.isAfter(DateTime.now());

  factory SmartAccessModel.fromJson(Map<String, dynamic> json) {
    final generated = json['generatedPin']?.toString();
    return SmartAccessModel(
      bookingId: json['bookingId']?.toString() ?? '',
      unitCode: json['unitCode']?.toString() ?? '',
      pinSet: json['pinSet'] == true,
      pinUpdatedAt: json['pinUpdatedAt'] != null
          ? DateTime.tryParse(json['pinUpdatedAt'].toString())
          : null,
      locked: json['locked'] == null ? true : json['locked'] == true,
      attemptsRemaining: (json['attemptsRemaining'] as num?)?.toInt() ?? 5,
      pinLockedUntil: json['pinLockedUntil'] != null
          ? DateTime.tryParse(json['pinLockedUntil'].toString())
          : null,
      generatedPin: (generated == null || generated.isEmpty) ? null : generated,
    );
  }
}
