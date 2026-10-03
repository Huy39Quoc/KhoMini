import '../models/facility_operations_models.dart';

class FacilityOperationsMapper {
  const FacilityOperationsMapper._();

  static AssignedFacilityModel assignedFacilityFromJson(
    Map<String, dynamic> json,
  ) {
    return AssignedFacilityModel(
      id: _text(json['id']),
      name: _text(json['name']),
      address: _text(json['address']),
    );
  }

  static DailyScheduleModel dailyScheduleFromJson(
    Map<String, dynamic> json,
  ) {
    return DailyScheduleModel(
      bookingId: _text(json['bookingId']),
      bookingCode: _text(json['bookingCode']),
      customerId: _text(json['customerId']),
      customerName: _text(json['customerName']),
      customerEmail: _text(json['customerEmail']),
      facilityId: _text(json['facilityId']),
      facilityName: _text(json['facilityName']),
      storageUnitId: _text(json['storageUnitId']),
      unitCode: _text(json['unitCode']),
      floorLevel: _text(json['floorLevel']),
      type: _text(json['type']),
      scheduledTime: _dateTime(json['scheduledTime']),
      scheduleType: _text(json['scheduleType']),
      bookingStatus: _text(json['bookingStatus']),
    );
  }

  static HandoverModel handoverFromJson(Map<String, dynamic> json) {
    return HandoverModel(
      bookingId: _text(json['bookingId']),
      bookingCode: _text(json['bookingCode']),
      storageUnitId: _text(json['storageUnitId']),
      unitCode: _text(json['unitCode']),
      recordType: _text(json['recordType']),
      unitCondition: _text(json['unitCondition']),
      lockCondition: _text(json['lockCondition']),
      notes: _text(json['notes']),
      bookingStatus: _text(json['bookingStatus']),
      unitStatus: _text(json['unitStatus']),
      staffId: _text(json['staffId']),
      staffName: _text(json['staffName']),
      recordedAt: _dateTime(json['recordedAt']),
      message: _text(json['message']),
    );
  }

  static HandoverRecordModel handoverRecordFromJson(
    Map<String, dynamic> json,
  ) {
    return HandoverRecordModel(
      id: _text(json['id']),
      bookingId: _text(json['bookingId']),
      recordType: _text(json['recordType']),
      unitCondition: _text(json['unitCondition']),
      notes: _text(json['notes']),
      staffId: _text(json['staffId']),
      staffName: _text(json['staffName']),
      recordedAt: _dateTime(json['recordedAt']),
    );
  }

  static Map<String, dynamic> handoverRequestToJson({
    required String unitCondition,
    required String lockCondition,
    String? notes,
  }) {
    final normalizedNotes = notes?.trim();

    return {
      'unitCondition': unitCondition.trim(),
      'lockCondition': lockCondition.trim(),
      if (normalizedNotes != null && normalizedNotes.isNotEmpty)
        'notes': normalizedNotes,
    };
  }

  static Map<String, dynamic> asJsonMap(dynamic value) {
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

  static DateTime? _dateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
