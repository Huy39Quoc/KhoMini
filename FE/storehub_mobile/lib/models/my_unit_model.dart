// Khớp với BE MyUnitResponse: { bookingId, bookingCode, facilityName,
// facilityAddress, unitCode, unitTypeName, dimensions, areaSqm, startDate,
// endDate, rentalMonths, status, totalRentalFee, depositPaid, hasActiveAccess }
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

  /// Current monthly rate derived from the real totalRentalFee /
  /// rentalMonths already returned by the BE - not a client-side estimate.
  double? get monthlyRate {
    if (rentalMonths == null || rentalMonths == 0) return null;
    return totalRentalFee / rentalMonths!;
  }

  // Giữ lại để không phá vỡ các chỗ đã dùng u.id trước đây.
  String get id => bookingId;

  factory MyUnitModel.fromJson(Map<String, dynamic> json) {
    return MyUnitModel(
      // Trước đây đọc "contractId"/"id" -> luôn rỗng vì BE trả về "bookingId",
      // khiến mọi API sau đó (smart access / extend / checkout) gọi với id rỗng.
      bookingId:
          json['bookingId']?.toString() ?? json['id']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      unitCode: json['unitCode']?.toString() ?? '',
      facilityName: json['facilityName']?.toString() ?? '',
      facilityAddress: json['facilityAddress']?.toString() ??
          json['address']?.toString() ??
          '',
      // Trước đây đọc "typeName" -> luôn rỗng vì BE trả về "unitTypeName".
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
      // Dùng trực tiếp cờ hasActiveAccess do BE trả về thay vì tự đoán qua status.
      hasActiveAccess: json['hasActiveAccess'] == true,
      dimensions: json['dimensions']?.toString() ?? '',
      areaSqm: (json['areaSqm'] as num?)?.toDouble(),
      rentalMonths: (json['rentalMonths'] as num?)?.toInt(),
      depositPaid: (json['depositPaid'] as num?)?.toDouble(),
    );
  }
}
