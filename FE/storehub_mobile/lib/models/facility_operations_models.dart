class AssignedFacilityModel {
  final String id;
  final String name;
  final String address;

  const AssignedFacilityModel({
    required this.id,
    required this.name,
    required this.address,
  });
}

class DailyScheduleModel {
  final String bookingId;
  final String bookingCode;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String facilityId;
  final String facilityName;
  final String storageUnitId;
  final String unitCode;
  final String floorLevel;
  final String type;
  final DateTime? scheduledTime;
  final String scheduleType;
  final String bookingStatus;

  const DailyScheduleModel({
    required this.bookingId,
    required this.bookingCode,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.facilityId,
    required this.facilityName,
    required this.storageUnitId,
    required this.unitCode,
    required this.floorLevel,
    required this.type,
    required this.scheduledTime,
    required this.scheduleType,
    required this.bookingStatus,
  });

  bool get isCheckIn => scheduleType.toUpperCase() == 'CHECK_IN';
}

class HandoverModel {
  final String bookingId;
  final String bookingCode;
  final String storageUnitId;
  final String unitCode;
  final String recordType;
  final String unitCondition;
  final String lockCondition;
  final String notes;
  final String bookingStatus;
  final String unitStatus;
  final String staffId;
  final String staffName;
  final DateTime? recordedAt;
  final String message;

  const HandoverModel({
    required this.bookingId,
    required this.bookingCode,
    required this.storageUnitId,
    required this.unitCode,
    required this.recordType,
    required this.unitCondition,
    required this.lockCondition,
    required this.notes,
    required this.bookingStatus,
    required this.unitStatus,
    required this.staffId,
    required this.staffName,
    required this.recordedAt,
    required this.message,
  });
}

class HandoverRecordModel {
  final String id;
  final String bookingId;
  final String recordType;
  final String unitCondition;
  final String notes;
  final String staffId;
  final String staffName;
  final DateTime? recordedAt;

  const HandoverRecordModel({
    required this.id,
    required this.bookingId,
    required this.recordType,
    required this.unitCondition,
    required this.notes,
    required this.staffId,
    required this.staffName,
    required this.recordedAt,
  });
}