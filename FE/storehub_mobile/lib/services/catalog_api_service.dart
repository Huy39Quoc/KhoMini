import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/facility_model.dart';

class CatalogApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<Map<String, dynamic>> getFacility(String facilityId) async {
    final response = await _dio.get(ApiEndpoints.facilityDetail(facilityId));
    final body = response.data;
    final facility = body is Map ? body['data'] : null;
    if (facility is! Map) throw const FormatException('Cơ sở không hợp lệ');
    return Map<String, dynamic>.from(facility);
  }

  Future<List<FacilityModel>> getFacilities() async {
    try {
      final response = await _dio.get(ApiEndpoints.facilities);
      final data = response.data;
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map && data['data'] is List) {
        raw = data['data'] as List;
      }
      return raw
          .map((e) => FacilityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được danh sách cơ sở: $message');
    }
  }

  Future<List<dynamic>> getUnitTypes({String? facilityId}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.unitTypes,
        queryParameters: facilityId != null && facilityId.isNotEmpty
            ? {'facilityId': facilityId}
            : null,
      );
      final data = response.data;
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'];
      return [];
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được loại kho: $message');
    }
  }

  Future<List<FacilityModel>> getFacilitiesWithStats() async {
    final facilities = await getFacilities();
    final enriched = await Future.wait(facilities.map((f) async {
      try {
        final unitTypes = await getUnitTypes(facilityId: f.id);
        return f.withUnitTypeStats(unitTypes);
      } catch (_) {
        return f;
      }
    }));
    return enriched;
  }

  Future<Map<String, dynamic>> getRentalQuote({
    required String unitTypeId,
    String? facilityId,
    required DateTime startDate,
    required int rentalMonths,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.pricingQuote,
        data: {
          'unitTypeId': unitTypeId,
          if (facilityId != null) 'facilityId': facilityId,
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
      throw Exception('Không tính được chi phí thuê: $message');
    }
  }

  Future<Map<String, dynamic>?> getFacilityPolicy(String facilityId) async {
    try {
      final response =
          await _dio.get(ApiEndpoints.facilityPolicyByFacility(facilityId));
      final body = response.data;
      if (body is Map && body['data'] is Map) {
        return Map<String, dynamic>.from(body['data']);
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  String _formatLocalDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}';
  }
}
