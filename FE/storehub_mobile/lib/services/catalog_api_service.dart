import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

// Trước đây FacilityDetailScreen dùng hoàn toàn dữ liệu giả (hard-code)
// và không gọi bất kỳ API nào. Service này gọi đúng các endpoint catalog và
// pricing đã có sẵn ở BE.
class CatalogApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<List<dynamic>> getUnitTypes({String? facilityId}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.unitTypes,
        queryParameters:
            facilityId != null && facilityId.isNotEmpty
                ? {'facilityId': facilityId}
                : null,
      );
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'];
      return [];
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load unit types: $message');
    }
  }

  Future<Map<String, dynamic>> getRentalQuote({
    required String unitTypeId,
    required DateTime startDate,
    required int rentalMonths,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.pricingQuote,
        data: {
          'unitTypeId': unitTypeId,
          'startDate': _formatLocalDate(startDate),
          'rentalMonths': rentalMonths,
        },
      );
      final data = response.data;
      final result = data is Map && data['data'] is Map ? data['data'] : data;
      return result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to get rental quote: $message');
    }
  }

  String _formatLocalDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}';
  }
}
