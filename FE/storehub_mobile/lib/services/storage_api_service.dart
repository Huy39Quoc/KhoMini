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

  // Lấy thông tin smart access (mã PIN / mã QR) theo bookingId.
  // BE trả về dạng bọc { success, message, data: { accessPin, ... } };
  // trước đây hàm này trả nguyên cả bọc đó ra ngoài (không bóc "data"),
  // khiến accessPin/qrCodeToken/tokenExpiresAt luôn bị đọc là null.
  Future<Map<String, dynamic>> getSmartAccess(String bookingId) async {
    try {
      final response = await _dio.get(ApiEndpoints.smartAccess(bookingId));
      return _unwrapMap(response.data);
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
  // Trả về nguyên ContractOperationResponse thật từ BE (newEndDate,
  // additionalFee, updatedTotalFee...) để FE hiển thị đúng số tiền thật,
  // thay vì tự tính (không có công thức thuế/giảm giá nào ở FE cả).
  Future<Map<String, dynamic>> extendRental(String bookingId, int months) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.extendRental(bookingId),
        data: {'extraMonths': months},
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to extend rental: $message');
    }
  }

  // Gửi yêu cầu trả kho (checkout)
  // BE (CheckoutRequest) bắt buộc "scheduledReturnTime" (phải ở tương lai);
  // trước đây không gửi gì nên luôn bị lỗi validate ở BE.
  // Cũng trả về ContractOperationResponse thật (message, scheduledReturnTime...).
  Future<Map<String, dynamic>> checkoutRental(
    String bookingId,
    DateTime scheduledReturnTime, {
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.checkoutRental(bookingId),
        data: {
          'scheduledReturnTime': _formatLocalDateTime(scheduledReturnTime),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to checkout rental: $message');
    }
  }

  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  // Format "yyyy-MM-ddTHH:mm:ss" (không có mili-giây/timezone) để khớp
  // với kiểu LocalDateTime ở BE.
  String _formatLocalDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}'
        'T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
