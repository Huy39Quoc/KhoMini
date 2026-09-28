import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../mappers/facility_operations_mapper.dart';
import '../models/facility_operations_models.dart';
import '../mappers/facility_management_mapper.dart';
import '../models/facility_management_models.dart';

class FacilityOpsApiService {
  final Dio _dio = HttpClient.instance.dio;

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return <String, dynamic>{};
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is Map && data['data'] is List) {
      return List<dynamic>.from(data['data']);
    }

    if (data is List) {
      return data;
    }

    return <dynamic>[];
  }

  Exception _err(DioException error, String action) {
    final responseData = error.response?.data;

    String? message;

    if (responseData is Map) {
      message = responseData['message']?.toString();
    }

    message ??= error.message;

    return Exception(
      'Failed to $action: ${message ?? 'Unknown error'}',
    );
  }

  List<dynamic> _unwrapPageContent(dynamic data) {
    if (data is Map) {
      final payload = data['data'];

      if (payload is Map && payload['content'] is List) {
        return List<dynamic>.from(
          payload['content'],
        );
      }

      if (data['content'] is List) {
        return List<dynamic>.from(
          data['content'],
        );
      }
    }

    return _unwrapList(data);
  }

  // =========================================================
  // Facility Manager - Flow 5
  // Tạm thời giữ Map/dynamic, sẽ đổi sang mapper khi làm Flow 5
  // =========================================================

  // =========================================================
// Facility Manager - Flow 5
// =========================================================

  Future<List<FacilityUnitModel>> getFacilityUnits(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityUnits(facilityId),
      );

      return _unwrapList(response.data)
          .map(FacilityManagementMapper.asJsonMap)
          .map(FacilityManagementMapper.unitFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'load units');
    }
  }

  Future<FacilityUnitModel> createFacilityUnit(
    String facilityId, {
    required String unitCode,
    String? floorLevel,
    required String unitTypeId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.facilityUnits(facilityId),
        data: FacilityManagementMapper.unitRequestToJson(
          unitCode: unitCode,
          floorLevel: floorLevel,
          unitTypeId: unitTypeId,
        ),
      );

      return FacilityManagementMapper.unitFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'create unit');
    }
  }

  Future<FacilityUnitModel> updateFacilityUnit(
    String facilityId,
    String unitId, {
    required String unitCode,
    String? floorLevel,
    required String unitTypeId,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.facilityUnitDetail(
          facilityId,
          unitId,
        ),
        data: FacilityManagementMapper.unitRequestToJson(
          unitCode: unitCode,
          floorLevel: floorLevel,
          unitTypeId: unitTypeId,
        ),
      );

      return FacilityManagementMapper.unitFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'update unit');
    }
  }

  Future<FacilityUnitModel> assignUnitToBooking(
    String facilityId,
    String bookingId,
    String unitId,
  ) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.facilityAssignUnit(
          facilityId,
          bookingId,
          unitId,
        ),
      );

      return FacilityManagementMapper.unitFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'assign unit to booking');
    }
  }

  Future<FacilityReportModel> getFacilityManagerReport(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityManagerReport(
          facilityId,
        ),
      );

      return FacilityManagementMapper.reportFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'load facility report');
    }
  }

  Future<List<FacilityStaffModel>> getFacilityStaff(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityStaffList(
          facilityId,
        ),
      );

      return _unwrapList(response.data)
          .map(FacilityManagementMapper.asJsonMap)
          .map(FacilityManagementMapper.staffFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'load staff list');
    }
  }

  Future<List<AssignableUserModel>> getAssignableUsers() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.users,
        queryParameters: {
          'page': 0,
          'size': 200,
          'isActive': true,
          'sortBy': 'fullName',
          'sortDir': 'asc',
        },
      );

      return _unwrapPageContent(response.data)
          .map(FacilityManagementMapper.asJsonMap)
          .map(
            FacilityManagementMapper.assignableUserFromJson,
          )
          .where(
            (user) => user.id.isNotEmpty && user.isActive,
          )
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'load assignable users');
    }
  }

  Future<FacilityStaffModel> assignStaffToFacility(
    String facilityId,
    String userId,
  ) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.facilityAssignStaff(
          facilityId,
          userId,
        ),
      );

      return FacilityManagementMapper.staffFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'assign staff');
    }
  }

  Future<void> unassignStaff(
    String facilityId,
    String userId,
  ) async {
    try {
      await _dio.delete(
        ApiEndpoints.facilityAssignStaff(
          facilityId,
          userId,
        ),
      );
    } on DioException catch (error) {
      throw _err(error, 'unassign staff');
    }
  }

  Future<List<FacilityBookingModel>> getConfirmedBookings(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityConfirmedBookings(facilityId),
      );

      return _unwrapList(response.data)
          .map(FacilityManagementMapper.asJsonMap)
          .map(FacilityManagementMapper.bookingFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'load confirmed bookings');
    }
  }
  // =========================================================
  // Facility Staff - Flow 2
  // Các response được chuyển sang model bằng mapper
  // =========================================================

  Future<AssignedFacilityModel> getAssignedFacility() async {
    try {
      final response = await _dio.get(ApiEndpoints.myFacility);

      return FacilityOperationsMapper.assignedFacilityFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      // BE trả 403 (ErrorCode.FORBIDDEN) khi tài khoản chưa được gán cơ sở
      // (users.facility_id null). Đó không phải lỗi hệ thống: trả model rỗng để
      // màn hình hiện "No facility assigned" thay vì "Something went wrong".
      if (error.response?.statusCode == 403) {
        return const AssignedFacilityModel(id: '', name: '', address: '');
      }
      throw _err(error, 'load your assigned facility');
    }
  }

  Future<List<DailyScheduleModel>> getDailySchedule({
    required String facilityId,
    required DateTime date,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.dailySchedule,
        queryParameters: {
          'facilityId': facilityId,
          'date': _formatDate(date),
        },
      );

      return _unwrapList(response.data)
          .map(FacilityOperationsMapper.asJsonMap)
          .map(FacilityOperationsMapper.dailyScheduleFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'load the daily schedule');
    }
  }

  Future<HandoverModel> checkIn({
    required String bookingId,
    required String facilityId,
    required String unitCondition,
    required String lockCondition,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.checkIn(bookingId),
        queryParameters: {
          'facilityId': facilityId,
        },
        data: FacilityOperationsMapper.handoverRequestToJson(
          unitCondition: unitCondition,
          lockCondition: lockCondition,
          notes: notes,
        ),
      );

      return FacilityOperationsMapper.handoverFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'check in this customer');
    }
  }

  Future<HandoverModel> checkOut({
    required String bookingId,
    required String facilityId,
    required String unitCondition,
    required String lockCondition,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.checkOut(bookingId),
        queryParameters: {
          'facilityId': facilityId,
        },
        data: FacilityOperationsMapper.handoverRequestToJson(
          unitCondition: unitCondition,
          lockCondition: lockCondition,
          notes: notes,
        ),
      );

      return FacilityOperationsMapper.handoverFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'complete check-out');
    }
  }

  Future<List<HandoverRecordModel>> getHandoverHistory({
    required String bookingId,
    required String facilityId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.handoverRecords(bookingId),
        queryParameters: {
          'facilityId': facilityId,
        },
      );

      return _unwrapList(response.data)
          .map(FacilityOperationsMapper.asJsonMap)
          .map(FacilityOperationsMapper.handoverRecordFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'load handover history');
    }
  }

  Future<void> updateUnitStatus({
    required String unitId,
    required String facilityId,
    required String status,
  }) async {
    try {
      await _dio.patch(
        ApiEndpoints.updateUnitStatus(unitId),
        queryParameters: {
          'facilityId': facilityId,
        },
        data: {
          'status': status,
        },
      );
    } on DioException catch (error) {
      throw _err(error, 'update unit status');
    }
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${date.year.toString().padLeft(4, '0')}'
        '-${twoDigits(date.month)}'
        '-${twoDigits(date.day)}';
  }
}
