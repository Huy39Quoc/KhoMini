class MyUnitModel {
  final String bookingId;
  final String bookingCode;
  final String facilityName;
  final String facilityAddress;
  final String unitCode;
  final String unitTypeName;
  final String dimensions;
  final double? areaSqm;
  final String startDate;
  final String endDate;
  final int rentalMonths;
  final String status;
  final double totalRentalFee;
  final double depositPaid;
  final bool hasActiveAccess;

  MyUnitModel({
    required this.bookingId,
    required this.bookingCode,
    required this.facilityName,
    required this.facilityAddress,
    required this.unitCode,
    required this.unitTypeName,
    required this.dimensions,
    this.areaSqm,
    required this.startDate,
    required this.endDate,
    required this.rentalMonths,
    required this.status,
    required this.totalRentalFee,
    required this.depositPaid,
    required this.hasActiveAccess,
  });

  factory MyUnitModel.fromJson(Map<String, dynamic> json) {
    return MyUnitModel(
      bookingId: json['bookingId']?.toString() ?? '',
      bookingCode: json['bookingCode'] ?? '',
      facilityName: json['facilityName'] ?? '',
      facilityAddress: json['facilityAddress'] ?? '',
      unitCode: json['unitCode'] ?? '',
      unitTypeName: json['unitTypeName'] ?? '',
      dimensions: json['dimensions'] ?? '',
      areaSqm:
          json['areaSqm'] != null ? (json['areaSqm'] as num).toDouble() : null,
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      rentalMonths: json['rentalMonths'] ?? 0,
      status: json['status'] ?? '',
      totalRentalFee: (json['totalRentalFee'] as num?)?.toDouble() ?? 0.0,
      depositPaid: (json['depositPaid'] as num?)?.toDouble() ?? 0.0,
      hasActiveAccess: json['hasActiveAccess'] ?? false,
    );
  }
}
