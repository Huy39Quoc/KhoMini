import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

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
      if (data is Map &&
          data['data'] is Map &&
          data['data']['content'] is List) {
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
      final response =
          await _dio.post(ApiEndpoints.facilitiesAdmin, data: body);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'create facility');
    }
  }

  Future<Map<String, dynamic>> updateFacility(
      String id, Map<String, dynamic> body) async {
    try {
      final response =
          await _dio.put(ApiEndpoints.facilityDetail(id), data: body);
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
      if (data is Map &&
          data['data'] is Map &&
          data['data']['content'] is List) {
        return data['data']['content'];
      }
      if (data is Map && data['content'] is List) return data['content'];
      return [];
    } on DioException catch (e) {
      throw _err(e, 'load facility policies');
    }
  }

  Future<Map<String, dynamic>?> getFacilityPolicyByFacility(
      String facilityId) async {
    try {
      final response =
          await _dio.get(ApiEndpoints.facilityPolicyByFacility(facilityId));
      return _unwrap(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _err(e, 'load this facility\'s policy');
    }
  }

  Future<Map<String, dynamic>> createFacilityPolicy(
      Map<String, dynamic> body) async {
    try {
      final response =
          await _dio.post(ApiEndpoints.facilityPolicies, data: body);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'create facility policy');
    }
  }

  Future<Map<String, dynamic>> updateFacilityPolicy(
      String id, Map<String, dynamic> body) async {
    try {
      final response =
          await _dio.put(ApiEndpoints.facilityPolicyDetail(id), data: body);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'update facility policy');
    }
  }

  Future<Map<String, dynamic>> getRevenueReport(
      {DateTime? fromDate, DateTime? toDate}) async {
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

  Future<String> exportReport({
    required String type,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.reportExport,
        queryParameters: {
          'type': type,
          if (fromDate != null) 'fromDate': _formatDate(fromDate),
          if (toDate != null) 'toDate': _formatDate(toDate),
        },
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': '*/*'},
        ),
      );
      return response.data?.toString() ?? '';
    } on DioException catch (e) {
      throw _err(e, 'export the report');
    }
  }

  Future<Map<String, dynamic>> updateUnitTypePrice({
    required String unitTypeId,
    required double basePricePerMonth,
    required double depositAmount,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.unitTypePrice(unitTypeId),
        data: {
          'basePricePerMonth': basePricePerMonth,
          'depositAmount': depositAmount,
        },
      );
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'update the unit type price');
    }
  }

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
      if (data is Map &&
          data['data'] is Map &&
          data['data']['content'] is List) {
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
      if (data is Map &&
          data['data'] is Map &&
          data['data']['content'] is List) {
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
