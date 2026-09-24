import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

/// Wires FacilityManagementController (Facility Manager: units, staff,
/// facility report, assigning a unit to a booking) and
/// FacilityOperationsController (Facility Staff: daily schedule, check-in,
/// check-out, unit status). Both controllers were only just merged onto
/// the BE - this is Member 4's entire Flow 2 / Flow 5 scope, previously
/// 0% wired on the FE because there was nothing to wire to.
class FacilityOpsApiService {
  final Dio _dio = HttpClient.instance.dio;

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is Map && data['data'] is List) return data['data'];
    if (data is List) return data;
    return [];
  }

  Exception _err(DioException e, String action) {
    final message = e.response?.data?['message'] ?? e.message;
    return Exception('Failed to $action: $message');
  }

  // ===== Facility Manager (FacilityManagementController) =====

  /// GET /facility/management/my-facility - the facility this Manager or
  /// Staff account is assigned to (User.facility on the BE).
  Future<Map<String, dynamic>> getMyFacility() async {
    try {
      final response = await _dio.get(ApiEndpoints.myFacility);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'load your assigned facility');
    }
  }

  Future<List<dynamic>> getFacilityUnits(String facilityId) async {
    try {
      final response = await _dio.get(ApiEndpoints.facilityUnits(facilityId));
      return _unwrapList(response.data);
    } on DioException catch (e) {
      throw _err(e, 'load units');
    }
  }

  Future<Map<String, dynamic>> createFacilityUnit(
    String facilityId, {
    required String unitCode,
    String? floorLevel,
    required String unitTypeId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.facilityUnits(facilityId),
        data: {
          'unitCode': unitCode,
          if (floorLevel != null && floorLevel.isNotEmpty) 'floorLevel': floorLevel,
          'unitTypeId': unitTypeId,
        },
      );
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'create unit');
    }
  }

  Future<Map<String, dynamic>> updateFacilityUnit(
    String facilityId,
    String unitId, {
    required String unitCode,
    String? floorLevel,
    required String unitTypeId,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.facilityUnitDetail(facilityId, unitId),
        data: {
          'unitCode': unitCode,
          if (floorLevel != null && floorLevel.isNotEmpty) 'floorLevel': floorLevel,
          'unitTypeId': unitTypeId,
        },
      );
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'update unit');
    }
  }

  Future<Map<String, dynamic>> assignUnitToBooking(
    String facilityId,
    String bookingId,
    String unitId,
  ) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.facilityAssignUnit(facilityId, bookingId, unitId),
      );
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'assign unit to booking');
    }
  }

  Future<Map<String, dynamic>> getFacilityManagerReport(String facilityId) async {
    try {
      final response = await _dio.get(ApiEndpoints.facilityManagerReport(facilityId));
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'load facility report');
    }
  }

  Future<List<dynamic>> getFacilityStaff(String facilityId) async {
    try {
      final response = await _dio.get(ApiEndpoints.facilityStaffList(facilityId));
      return _unwrapList(response.data);
    } on DioException catch (e) {
      throw _err(e, 'load staff list');
    }
  }

  Future<Map<String, dynamic>> assignStaffToFacility(String facilityId, String userId) async {
    try {
      final response = await _dio.put(ApiEndpoints.facilityAssignStaff(facilityId, userId));
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'assign staff');
    }
  }

  Future<void> unassignStaff(String facilityId, String userId) async {
    try {
      await _dio.delete(ApiEndpoints.facilityAssignStaff(facilityId, userId));
    } on DioException catch (e) {
      throw _err(e, 'unassign staff');
    }
  }

  // ===== Facility Staff (FacilityOperationsController) =====

  Future<List<dynamic>> getDailySchedule({
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
      return _unwrapList(response.data);
    } on DioException catch (e) {
      throw _err(e, 'load the daily schedule');
    }
  }

  Future<Map<String, dynamic>> checkIn({
    required String bookingId,
    required String facilityId,
    required String unitCondition,
    required String lockCondition,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.checkIn(bookingId),
        queryParameters: {'facilityId': facilityId},
        data: {
          'unitCondition': unitCondition,
          'lockCondition': lockCondition,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'check in this customer');
    }
  }

  Future<Map<String, dynamic>> checkOut({
    required String bookingId,
    required String facilityId,
    required String unitCondition,
    required String lockCondition,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.checkOut(bookingId),
        queryParameters: {'facilityId': facilityId},
        data: {
          'unitCondition': unitCondition,
          'lockCondition': lockCondition,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'complete check-out');
    }
  }

  /// status must match com.storehub.enums.UnitStatus: AVAILABLE, RESERVED,
  /// OCCUPIED, UNDER_MAINTENANCE.
  Future<void> updateUnitStatus({
    required String unitId,
    required String facilityId,
    required String status,
  }) async {
    try {
      await _dio.patch(
        ApiEndpoints.updateUnitStatus(unitId),
        queryParameters: {'facilityId': facilityId},
        data: {'status': status},
      );
    } on DioException catch (e) {
      throw _err(e, 'update unit status');
    }
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}';
  }
}
