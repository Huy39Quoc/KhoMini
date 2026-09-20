class MyUnitModel {
  final String bookingId;
  final String bookingCode;
  final String unitCode;
  final String facilityName;
  final String facilityAddress;
  final String typeName;
  final String status;
  final double totalRentalFee;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool hasActiveAccess;
  final String dimensions;
  final double? areaSqm;
  final int? rentalMonths;
  final double? depositPaid;

  MyUnitModel({
    required this.bookingId,
    required this.bookingCode,
    required this.unitCode,
    required this.facilityName,
    required this.facilityAddress,
    required this.typeName,
    required this.status,
    required this.totalRentalFee,
    this.startDate,
    this.endDate,
    this.hasActiveAccess = false,
    this.dimensions = '',
    this.areaSqm,
    this.rentalMonths,
    this.depositPaid,
  });

  double? get monthlyRate {
    if (rentalMonths == null || rentalMonths == 0) return null;
    return totalRentalFee / rentalMonths!;
  }

  String get id => bookingId;

  factory MyUnitModel.fromJson(Map<String, dynamic> json) {
    return MyUnitModel(
      bookingId:
          json['bookingId']?.toString() ?? json['id']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      unitCode: json['unitCode']?.toString() ?? '',
      facilityName: json['facilityName']?.toString() ?? '',
      facilityAddress: json['facilityAddress']?.toString() ??
          json['address']?.toString() ??
          '',
      typeName: json['unitTypeName']?.toString() ??
          json['typeName']?.toString() ??
          '',
      status: json['status']?.toString() ?? '',
      totalRentalFee: (json['totalRentalFee'] as num?)?.toDouble() ??
          (json['rentalPrice'] as num?)?.toDouble() ??
          0.0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      hasActiveAccess: json['hasActiveAccess'] == true,
      dimensions: json['dimensions']?.toString() ?? '',
      areaSqm: (json['areaSqm'] as num?)?.toDouble(),
      rentalMonths: (json['rentalMonths'] as num?)?.toInt(),
      depositPaid: (json['depositPaid'] as num?)?.toDouble(),
    );
  }
}
