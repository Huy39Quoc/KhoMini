import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/paged_result.dart';

class FacilityAdminApiService {
  final HttpClient _http = HttpClient.instance;

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Exception _err(ApiException e, String action) {
    final message = e.response?.data?['message'] ?? e.message;
    return Exception('Không thể $action: $message');
  }

  Future<int> getFacilitiesCount() async {
    try {
      final response = await _http.get(
        ApiEndpoints.facilitiesAdmin,
        queryParameters: {'page': 0, 'size': 1},
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final total = data['data']['totalElements'];
        if (total is num) return total.toInt();
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<dynamic>> getFacilities({String? search}) async {
    final all = <dynamic>[];
    var page = 0;
    while (true) {
      final batch = await getFacilitiesPage(search: search, page: page++);
      all.addAll(batch.content);
      if (batch.last) return all;
    }
  }

  Future<PagedResult<Map<String, dynamic>>> getFacilitiesPage(
      {String? search, int page = 0}) async {
    try {
      final response = await _http.get(
        ApiEndpoints.facilitiesAdmin,
        queryParameters: {
          'page': page,
          'size': 20,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      return PagedResult.fromApi(response.data,
          (item) => Map<String, dynamic>.from(item as Map));
    } on ApiException catch (e) {
      throw _err(e, 'tải danh sách cơ sở');
    }
  }

  Future<Map<String, dynamic>> createFacility(Map<String, dynamic> body) async {
    try {
      final response =
          await _http.post(ApiEndpoints.facilitiesAdmin, data: body);
      return _unwrap(response.data);
    } on ApiException catch (e) {
      throw _err(e, 'tạo cơ sở');
    }
  }

  Future<Map<String, dynamic>> updateFacility(
      String id, Map<String, dynamic> body) async {
    try {
      final response =
          await _http.put(ApiEndpoints.facilityDetail(id), data: body);
      return _unwrap(response.data);
    } on ApiException catch (e) {
      throw _err(e, 'cập nhật cơ sở');
    }
  }

  Future<String> uploadFacilityImage(String filePath, {String? facilityId}) async {
    try {
      final url = (facilityId != null && facilityId.isNotEmpty)
          ? '${ApiEndpoints.facilitiesAdmin}/$facilityId/image'
          : '${ApiEndpoints.facilitiesAdmin}/upload-image';

      final response = await _http.post(
        url,
        data: ApiMultipart([ApiUploadFile('file', filePath)]),
      );
      if (response.data is Map && response.data['data'] != null) {
        return response.data['data'].toString();
      }
      return '';
    } on ApiException catch (e) {
      throw _err(e, 'tải ảnh lên');
    }
  }

  Future<List<String>> uploadFacilityImages(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];
    try {
      final response = await _http.post(
        '${ApiEndpoints.facilitiesAdmin}/upload-images',
        data: ApiMultipart([
          for (final path in filePaths) ApiUploadFile('files', path),
        ]),
      );
      if (response.data is Map && response.data['data'] is List) {
        return (response.data['data'] as List).map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      final results = <String>[];
      for (final p in filePaths) {
        final url = await uploadFacilityImage(p);
        if (url.isNotEmpty) results.add(url);
      }
      return results;
    }
  }

  Future<void> deleteFacility(String id) async {
    try {
      await _http.delete(ApiEndpoints.facilityDetail(id));
    } on ApiException catch (e) {
      throw _err(e, 'xóa cơ sở');
    }
  }

  Future<List<dynamic>> getFacilityPolicies({String? search}) async {
    try {
      final response = await _http.get(
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
    } on ApiException catch (e) {
      throw _err(e, 'tải chính sách cơ sở');
    }
  }

  Future<Map<String, dynamic>?> getFacilityPolicyByFacility(
      String facilityId) async {
    try {
      final response =
          await _http.get(ApiEndpoints.facilityPolicyByFacility(facilityId));
      return _unwrap(response.data);
    } on ApiException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _err(e, 'tải chính sách của cơ sở này');
    }
  }

  Future<Map<String, dynamic>> createFacilityPolicy(
      Map<String, dynamic> body) async {
    try {
      final response =
          await _http.post(ApiEndpoints.facilityPolicies, data: body);
      return _unwrap(response.data);
    } on ApiException catch (e) {
      throw _err(e, 'tạo chính sách cơ sở');
    }
  }

  Future<Map<String, dynamic>> updateFacilityPolicy(
      String id, Map<String, dynamic> body) async {
    try {
      final response =
          await _http.put(ApiEndpoints.facilityPolicyDetail(id), data: body);
      return _unwrap(response.data);
    } on ApiException catch (e) {
      throw _err(e, 'cập nhật chính sách cơ sở');
    }
  }

  Future<Map<String, dynamic>> getRevenueReport(
      {DateTime? fromDate, DateTime? toDate}) async {
    try {
      final response = await _http.get(
        ApiEndpoints.reportRevenue,
        queryParameters: {
          if (fromDate != null) 'fromDate': _formatDate(fromDate),
          if (toDate != null) 'toDate': _formatDate(toDate),
        },
      );
      return _unwrap(response.data);
    } on ApiException catch (e) {
      throw _err(e, 'tải báo cáo doanh thu');
    }
  }

  Future<Map<String, dynamic>> getOccupancyReport() async {
    try {
      final response = await _http.get(ApiEndpoints.reportOccupancy);
      return _unwrap(response.data);
    } on ApiException catch (e) {
      throw _err(e, 'tải báo cáo lấp đầy');
    }
  }

  Future<String> exportReport({
    required String type,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final response = await _http.get(
        ApiEndpoints.reportExport,
        queryParameters: {
          'type': type,
          if (fromDate != null) 'fromDate': _formatDate(fromDate),
          if (toDate != null) 'toDate': _formatDate(toDate),
        },
        plainText: true,
      );
      return response.data?.toString() ?? '';
    } on ApiException catch (e) {
      throw _err(e, 'xuất báo cáo');
    }
  }

  Future<Map<String, dynamic>> updateUnitTypePrice({
    required String unitTypeId,
    required double basePricePerMonth,
    required double depositAmount,
  }) async {
    try {
      final response = await _http.put(
        ApiEndpoints.unitTypePrice(unitTypeId),
        data: {
          'basePricePerMonth': basePricePerMonth,
          'depositAmount': depositAmount,
        },
      );
      return _unwrap(response.data);
    } on ApiException catch (e) {
      throw _err(e, 'cập nhật giá loại kho');
    }
  }

  Future<List<dynamic>> getActivityLogs({
    String? search,
    bool? criticalOnly,
    int page = 0,
    int size = 30,
  }) async {
    try {
      final response = await _http.get(
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
    } on ApiException catch (e) {
      throw _err(e, 'tải nhật ký hoạt động');
    }
  }

  Future<List<dynamic>> getLoginHistory({int page = 0, int size = 30}) async {
    try {
      final response = await _http.get(
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
    } on ApiException catch (e) {
      throw _err(e, 'tải lịch sử đăng nhập');
    }
  }

  Future<Map<String, dynamic>> getActivityLogDetail(String id) async {
    try {
      final response = await _http.get(ApiEndpoints.activityLogDetail(id));
      return _unwrap(response.data);
    } on ApiException catch (e) {
      throw _err(e, 'tải chi tiết nhật ký');
    }
  }

  Future<Map<String, dynamic>> getFacilityPolicyById(String id) async {
    try {
      final response = await _http.get(ApiEndpoints.facilityPolicyDetail(id));
      return _unwrap(response.data);
    } on ApiException catch (e) {
      throw _err(e, 'tải chính sách cơ sở');
    }
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}';
  }
}
