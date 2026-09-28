class FacilityUnitModel {
  final String id;
  final String unitCode;
  final String floorLevel;
  final String unitTypeId;
  final String unitType;
  final String status;

  const FacilityUnitModel({
    required this.id,
    required this.unitCode,
    required this.floorLevel,
    required this.unitTypeId,
    required this.unitType,
    required this.status,
  });

  String get statusLabel {
    return status.replaceAll('_', ' ');
  }

  bool get isAvailable {
    return status == 'AVAILABLE';
  }
}

class FacilityStaffModel {
  final String id;
  final String fullName;
  final String email;
  final String role;

  const FacilityStaffModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });
}

class FacilityReportModel {
  final String facilityId;
  final int total;
  final int available;
  final int reserved;
  final int occupied;
  final int underMaintenance;
  final int overdueBookings;
  final double occupancyRate;

  const FacilityReportModel({
    required this.facilityId,
    required this.total,
    required this.available,
    required this.reserved,
    required this.occupied,
    required this.underMaintenance,
    required this.overdueBookings,
    required this.occupancyRate,
  });
}

class AssignableUserModel {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final bool isActive;

  const AssignableUserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.isActive,
  });

  String get displayName {
    if (fullName.isNotEmpty) {
      return fullName;
    }

    if (username.isNotEmpty) {
      return username;
    }

    return email;
  }
}