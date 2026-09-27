import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

/// Wires FacilityController, FacilityPolicyController, ReportController and
/// ActivityLogController - these were merged onto the BE after the
/// operations/admin dashboards were first built, so the FE never had real
/// revenue/occupancy numbers or a facility/policy manager until now.
class FacilityAdminApiService {
  final Dio _dio = HttpClient.instance.dio;

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Exception _err(DioException e, String action) {
    final message = e.response?.data?['message'] ?? e.message;
    return Exception('Failed to $action: $message');
  }

  // ===== Facilities (FacilityController) =====

  Future<List<dynamic>> getFacilities({String? search}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilitiesAdmin,
        queryParameters: {
          'size': 200,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      }
      if (data is Map && data['content'] is List) return data['content'];
      return [];
    } on DioException catch (e) {
      throw _err(e, 'load facilities');
    }
  }

  Future<Map<String, dynamic>> createFacility(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(ApiEndpoints.facilitiesAdmin, data: body);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'create facility');
    }
  }

  Future<Map<String, dynamic>> updateFacility(String id, Map<String, dynamic> body) async {
    try {
      final response = await _dio.put(ApiEndpoints.facilityDetail(id), data: body);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'update facility');
    }
  }

  Future<void> deleteFacility(String id) async {
    try {
      await _dio.delete(ApiEndpoints.facilityDetail(id));
    } on DioException catch (e) {
      throw _err(e, 'delete facility');
    }
  }

  // ===== Facility Policies (FacilityPolicyController) =====

  Future<List<dynamic>> getFacilityPolicies({String? search}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityPolicies,
        queryParameters: {
          'size': 200,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      }
      if (data is Map && data['content'] is List) return data['content'];
      return [];
    } on DioException catch (e) {
      throw _err(e, 'load facility policies');
    }
  }

  Future<Map<String, dynamic>?> getFacilityPolicyByFacility(String facilityId) async {
    try {
      final response = await _dio.get(ApiEndpoints.facilityPolicyByFacility(facilityId));
      return _unwrap(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _err(e, 'load this facility\'s policy');
    }
  }

  Future<Map<String, dynamic>> createFacilityPolicy(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(ApiEndpoints.facilityPolicies, data: body);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'create facility policy');
    }
  }

  Future<Map<String, dynamic>> updateFacilityPolicy(String id, Map<String, dynamic> body) async {
    try {
      final response = await _dio.put(ApiEndpoints.facilityPolicyDetail(id), data: body);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'update facility policy');
    }
  }

  // ===== Reports (ReportController) =====

  Future<Map<String, dynamic>> getRevenueReport({DateTime? fromDate, DateTime? toDate}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.reportRevenue,
        queryParameters: {
          if (fromDate != null) 'fromDate': _formatDate(fromDate),
          if (toDate != null) 'toDate': _formatDate(toDate),
        },
      );
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'load the revenue report');
    }
  }

  Future<Map<String, dynamic>> getOccupancyReport() async {
    try {
      final response = await _dio.get(ApiEndpoints.reportOccupancy);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'load the occupancy report');
    }
  }

  // ===== Activity Log (ActivityLogController) =====

  Future<List<dynamic>> getActivityLogs({
    String? search,
    bool? criticalOnly,
    int page = 0,
    int size = 30,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.activityLogs,
        queryParameters: {
          'page': page,
          'size': size,
          if (search != null && search.isNotEmpty) 'search': search,
          if (criticalOnly == true) 'isCriticalOnly': true,
        },
      );
      final data = response.data;
      if (data is Map && data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      }
      return [];
    } on DioException catch (e) {
      throw _err(e, 'load activity logs');
    }
  }

  Future<List<dynamic>> getLoginHistory({int page = 0, int size = 30}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.activityLogLoginHistory,
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data;
      if (data is Map && data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      }
      return [];
    } on DioException catch (e) {
      throw _err(e, 'load login history');
    }
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}';
  }
}
