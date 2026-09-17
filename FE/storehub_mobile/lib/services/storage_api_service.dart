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
  // BE (UpdatePinRequest) nhận field tên "newPin", không phải "pin".
  Future<void> updatePin(String bookingId, String newPin) async {
    try {
      await _dio.put(
        ApiEndpoints.updatePin(bookingId),
        data: {'newPin': newPin},
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to update PIN: $message');
    }
  }

  // Gia hạn thời gian thuê kho
  // BE (ExtendRentalRequest) nhận field tên "extraMonths", không phải "months".
  Future<void> extendRental(String bookingId, int months) async {
    try {
      await _dio.post(
        ApiEndpoints.extendRental(bookingId),
        data: {'extraMonths': months},
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to extend rental: $message');
    }
  }

  // Gửi yêu cầu trả kho (checkout)
  // BE (CheckoutRequest) bắt buộc "scheduledReturnTime" (phải ở tương lai);
  // trước đây không gửi gì nên luôn bị lỗi validate ở BE.
  Future<void> checkoutRental(
    String bookingId,
    DateTime scheduledReturnTime, {
    String? notes,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.checkoutRental(bookingId),
        data: {
          'scheduledReturnTime': _formatLocalDateTime(scheduledReturnTime),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to checkout rental: $message');
    }
  }

  // Format "yyyy-MM-ddTHH:mm:ss" (không có mili-giây/timezone) để khớp
  // với kiểu LocalDateTime ở BE.
  String _formatLocalDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}'
        'T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
