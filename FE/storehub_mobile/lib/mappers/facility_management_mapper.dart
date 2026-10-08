import '../models/facility_management_models.dart';

class FacilityManagementMapper {
  const FacilityManagementMapper._();

  static FacilityUnitModel unitFromJson(
    Map<String, dynamic> json,
  ) {
    return FacilityUnitModel(
      id: _text(json['id']),
      unitCode: _text(json['unitCode']),
      floorLevel: _text(json['floorLevel']),
      unitTypeId: _text(json['unitTypeId']),
      unitType: _text(json['unitType']),
      status: _text(json['status']),
    );
  }

  static FacilityStaffModel staffFromJson(
    Map<String, dynamic> json,
  ) {
    return FacilityStaffModel(
      id: _text(json['id']),
      fullName: _text(json['fullName']),
      email: _text(json['email']),
      role: _text(json['role']),
    );
  }

  static FacilityReportModel reportFromJson(
    Map<String, dynamic> json,
  ) {
    return FacilityReportModel(
      facilityId: _text(json['facilityId']),
      total: _integer(json['total']),
      available: _integer(json['available']),
      reserved: _integer(json['reserved']),
      occupied: _integer(json['occupied']),
      underMaintenance: _integer(json['underMaintenance']),
      overdueBookings: _integer(json['overdueBookings']),
      occupancyRate: _decimal(json['occupancyRate']),
      revenue: _decimal(json['revenue']),
    );
  }

  static AssignableUserModel assignableUserFromJson(
    Map<String, dynamic> json,
  ) {
    return AssignableUserModel(
      id: _text(json['id']),
      username: _text(json['username']),
      fullName: _text(json['fullName']),
      email: _text(json['email']),
      isActive: json['isActive'] == true,
      roleName: _text(json['roleName']),
    );
  }

  static Map<String, dynamic> unitRequestToJson({
    required String unitCode,
    required String unitTypeId,
    String? floorLevel,
  }) {
    final normalizedFloor = floorLevel?.trim();

    return {
      'unitCode': unitCode.trim(),
      'unitTypeId': unitTypeId,
      if (normalizedFloor != null && normalizedFloor.isNotEmpty)
        'floorLevel': normalizedFloor,
    };
  }

  static Map<String, dynamic> asJsonMap(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static String _text(dynamic value) {
    return value?.toString() ?? '';
  }

  static int _integer(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _decimal(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static FacilityBookingModel bookingFromJson(
    Map<String, dynamic> json,
  ) {
    return FacilityBookingModel(
      id: _text(json['bookingId']),
      bookingCode: _text(json['bookingCode']),
      customerName: _text(json['customerName']),
      customerEmail: _text(json['customerEmail']),
      startDate: _text(json['startDate']),
      endDate: _text(json['endDate']),
      storageUnitId: _text(json['storageUnitId']),
      unitCode: _text(json['unitCode']),
      unitTypeId: _text(json['unitTypeId']),
      unitType: _text(json['unitType']),
      status: _text(json['status']),
    );
  }

  static FacilityContractModel contractFromJson(Map<String, dynamic> json) {
    return FacilityContractModel(
      bookingId: _text(json['bookingId']),
      bookingCode: _text(json['bookingCode']),
      customerName: _text(json['customerName']),
      customerEmail: _text(json['customerEmail']),
      unitCode: _text(json['unitCode']),
      unitType: _text(json['unitType']),
      startDate: _text(json['startDate']),
      endDate: _text(json['endDate']),
      rentalMonths: _integer(json['rentalMonths']),
      status: _text(json['status']),
      depositPaid: _decimal(json['depositPaid']),
      totalRentalFee: _decimal(json['totalRentalFee']),
      returnTime: json['returnTime']?.toString(),
      overdue: json['overdue'] == true,
      overdueDays: _integer(json['overdueDays']),
      overdueFeeAccrued: _decimal(json['overdueFeeAccrued']),
      accessDisabled: json['accessDisabled'] == true,
      sealingPending: json['sealingPending'] == true,
      pendingExtensionFee: json['pendingExtensionFee'] == null
          ? null
          : _decimal(json['pendingExtensionFee']),
      sealingApproved: json['sealingApproved'] == true,
    );
  }
}
