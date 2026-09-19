import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/facility_model.dart';

// Trước đây FacilityDetailScreen dùng hoàn toàn dữ liệu giả (hard-code)
// và không gọi bất kỳ API nào. Service này gọi đúng các endpoint catalog và
// pricing đã có sẵn ở BE.
class CatalogApiService {
  final Dio _dio = HttpClient.instance.dio;

  /// Lấy danh sách chi nhánh với các bộ lọc tuỳ chọn.
  /// Fallback về dữ liệu demo nếu BE chưa hỗ trợ endpoint này.
  Future<List<FacilityModel>> getFacilities({
    String? city,
    String? district,
    double? minArea,
    double? maxArea,
    bool? has24hAC,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (city != null && city.isNotEmpty) params['city'] = city;
      if (district != null && district.isNotEmpty) params['district'] = district;
      if (minArea != null) params['minArea'] = minArea;
      if (maxArea != null) params['maxArea'] = maxArea;
      if (has24hAC != null) params['has24hAC'] = has24hAC;

      final response = await _dio.get(
        ApiEndpoints.facilities,
        queryParameters: params.isNotEmpty ? params : null,
      );
      final data = response.data;
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map && data['data'] is List) {
        raw = data['data'] as List;
      } else if (data is Map && data['result'] is List) {
        raw = data['result'] as List;
      }
      return raw
          .map((e) => FacilityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException {
      // Nếu BE chưa có endpoint hoặc lỗi mạng → trả về dữ liệu demo
      return _demoFacilities();
    }
  }

  /// Dữ liệu demo dùng khi BE chưa sẵn sàng hoặc offline
  List<FacilityModel> _demoFacilities() => [
        FacilityModel(
          id: 'f-001',
          name: 'KhoMini Quận 1',
          address: '123 Lê Lợi',
          district: 'Quận 1',
          city: 'TP. Hồ Chí Minh',
          has24hAC: true,
          minAreaSqm: 2.0,
          maxAreaSqm: 20.0,
          totalUnits: 50,
          availableUnits: 12,
          minPricePerMonth: 500000,
        ),
        FacilityModel(
          id: 'f-002',
          name: 'KhoMini Quận 7',
          address: '45 Nguyễn Thị Thập',
          district: 'Quận 7',
          city: 'TP. Hồ Chí Minh',
          has24hAC: true,
          minAreaSqm: 3.0,
          maxAreaSqm: 30.0,
          totalUnits: 80,
          availableUnits: 25,
          minPricePerMonth: 450000,
        ),
        FacilityModel(
          id: 'f-003',
          name: 'KhoMini Bình Thạnh',
          address: '78 Đinh Bộ Lĩnh',
          district: 'Bình Thạnh',
          city: 'TP. Hồ Chí Minh',
          has24hAC: false,
          minAreaSqm: 1.5,
          maxAreaSqm: 15.0,
          totalUnits: 40,
          availableUnits: 8,
          minPricePerMonth: 380000,
        ),
        FacilityModel(
          id: 'f-004',
          name: 'KhoMini Thủ Đức',
          address: '12 Võ Văn Ngân',
          district: 'Thủ Đức',
          city: 'TP. Hồ Chí Minh',
          has24hAC: true,
          minAreaSqm: 2.0,
          maxAreaSqm: 25.0,
          totalUnits: 60,
          availableUnits: 18,
          minPricePerMonth: 420000,
        ),
      ];

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
