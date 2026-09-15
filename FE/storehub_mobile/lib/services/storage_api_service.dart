import 'package:dio/dio.dart';
import '../core/network/http_client.dart';
import '../core/constants/api_endpoints.dart';

class StorageApiService {
  // Get active rented storage units
  Future<List<dynamic>> getMyRentedUnits() async {
    try {
      final response = await HttpClient.instance.get(ApiEndpoints.myUnits);
      if (response.statusCode == 200) {
        final data = response.data;
        return data is List ? data : (data['content'] ?? []);
      }
      throw Exception('Failed to load rented units');
    } on DioException catch (e) {
      throw Exception(
          e.response?.data['message'] ?? 'Failed to connect to server');
    }
  }

  // Get Smart Key access details (PIN & QR)
  Future<Map<String, dynamic>> getSmartAccess(String unitId) async {
    try {
      final response =
          await HttpClient.instance.get(ApiEndpoints.smartAccess(unitId));
      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('Failed to fetch smart access info');
    } on DioException catch (e) {
      throw Exception(
          e.response?.data['message'] ?? 'Error fetching smart access');
    }
  }

  // Extend rental contract
  Future<bool> extendRental(String contractId, int months) async {
    try {
      final response = await HttpClient.instance.post(
        ApiEndpoints.extendRental(contractId),
        data: {'months': months},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data['message'] ?? 'Failed to extend contract');
    }
  }

  // Request unit checkout (return)
  Future<bool> checkoutRental(String contractId) async {
    try {
      final response = await HttpClient.instance
          .post(ApiEndpoints.checkoutRental(contractId));
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to checkout unit');
    }
  }

  // Submit support ticket
  Future<bool> submitTicket(
      String category, String description, String unitId) async {
    try {
      final response = await HttpClient.instance.post(
        ApiEndpoints.tickets,
        data: {
          'category': category,
          'description': description,
          'unitId': unitId,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data['message'] ?? 'Failed to submit support ticket');
    }
  }
}
