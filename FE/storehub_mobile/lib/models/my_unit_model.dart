class MyUnitModel {
  final String contractId;
  final String unitId;
  final String unitCode;
  final String facilityName;
  final String facilityAddress;
  final String typeName;
  final String status;
  final double totalRentalFee;
  final DateTime? startDate;
  final DateTime? endDate;

  MyUnitModel({
    required this.contractId,
    required this.unitId,
    required this.unitCode,
    required this.facilityName,
    required this.facilityAddress,
    required this.typeName,
    required this.status,
    required this.totalRentalFee,
    this.startDate,
    this.endDate,
  });

  String get id => contractId;
  String get bookingId => contractId;
  bool get hasActiveAccess =>
      status.toUpperCase() == 'ACTIVE' || status.toUpperCase() == 'RENTED';

  factory MyUnitModel.fromJson(Map<String, dynamic> json) {
    return MyUnitModel(
      contractId:
          json['contractId']?.toString() ?? json['id']?.toString() ?? '',
      unitId: json['unitId']?.toString() ?? '',
      unitCode: json['unitCode'] ?? '',
      facilityName: json['facilityName'] ?? '',
      facilityAddress: json['facilityAddress'] ?? json['address'] ?? '',
      typeName: json['typeName'] ?? '',
      status: json['status'] ?? '',
      totalRentalFee: (json['totalRentalFee'] as num?)?.toDouble() ??
          (json['rentalPrice'] as num?)?.toDouble() ??
          0.0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate:
          json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
    );
  }
}
