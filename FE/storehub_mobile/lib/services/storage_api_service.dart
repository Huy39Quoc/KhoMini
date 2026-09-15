import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

class StorageApiService {
  final Dio _dio = HttpClient.instance.dio;

  // Lấy danh sách kho đang thuê của khách hàng
  Future<List<dynamic>> getMyRentedUnits() async {
    try {
      final response = await _dio.get(ApiEndpoints.myUnits);
      if (response.data is List) {
        return response.data;
      } else if (response.data['result'] is List) {
        return response.data['result'];
      } else if (response.data['data'] is List) {
        return response.data['data'];
      }
      return [];
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load rented units: $message');
    }
  }

  // Lấy thông tin smart access (mã PIN / mã QR) theo bookingId
  Future<Map<String, dynamic>> getSmartAccess(String bookingId) async {
    try {
      final response = await _dio.get(ApiEndpoints.smartAccess(bookingId));
      return response.data is Map<String, dynamic>
          ? response.data
          : Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to get smart access: $message');
    }
  }

  // Cập nhật mã PIN mới cho ngăn kho
  Future<void> updatePin(String bookingId, String newPin) async {
    try {
      await _dio.put(ApiEndpoints.updatePin(bookingId), data: {'pin': newPin});
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to update PIN: $message');
    }
  }

  // Gia hạn thời gian thuê kho
  Future<void> extendRental(String bookingId, int months) async {
    try {
      await _dio.post(
        ApiEndpoints.extendRental(bookingId),
        data: {'months': months},
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to extend rental: $message');
    }
  }

  // Gửi yêu cầu trả kho (checkout)
  Future<void> checkoutRental(String bookingId) async {
    try {
      await _dio.post(ApiEndpoints.checkoutRental(bookingId));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to checkout rental: $message');
    }
  }
}
