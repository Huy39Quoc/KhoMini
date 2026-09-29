import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/facility_model.dart';

class CatalogApiService {
  final Dio _dio = HttpClient.instance.dio;

  /// GET /catalog/facilities - CatalogController.getFacilities() takes no
  /// query parameters at all (it just returns every facility), so no
  /// filters are sent here; filtering happens client-side in ExploreScreen.
  /// Previously this silently fell back to hard-coded demo facilities on
  /// ANY failure (network error, auth error, 500...) which could show fake
  /// data to the user with no indication it wasn't real. Now it throws like
  /// every other service method, so the screen can show a real error state.
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
      throw Exception('Failed to load facilities: $message');
    }
  }

  /// GET /catalog/unit-types?facilityId=... - real per-unit-type data
  /// (dimensions, areaSqm, basePricePerMonth, availableUnitsCount).
  /// FacilityResponse itself doesn't carry area/price/availability, so
  /// ExploreScreen aggregates this per facility to show real numbers
  /// instead of guessing at fields the BE doesn't return.
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

  /// Convenience: facility list, each enriched with real stats computed
  /// from its unit types (min/max area, cheapest monthly rate, units
  /// available right now). One request per facility, run in parallel -
  /// acceptable for the small number of facilities a self-storage business
  /// actually has.
  Future<List<FacilityModel>> getFacilitiesWithStats() async {
    final facilities = await getFacilities();
    final enriched = await Future.wait(facilities.map((f) async {
      try {
        final unitTypes = await getUnitTypes(facilityId: f.id);
        return f.withUnitTypeStats(unitTypes);
      } catch (_) {
        // If a single facility's unit-type lookup fails, still show the
        // facility itself rather than failing the whole list - its stats
        // just stay at "not available" instead of guessed values.
        return f;
      }
    }));
    return enriched;
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
