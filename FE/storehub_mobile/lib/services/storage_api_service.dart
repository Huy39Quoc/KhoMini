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

  // Lấy trạng thái smart access (đã có PIN chưa, đang khóa/mở). Server không trả PIN đã lưu.
  Future<Map<String, dynamic>> getSmartAccess(String bookingId) async {
    try {
      final response = await _dio.get(ApiEndpoints.smartAccess(bookingId));
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to get smart access: $message');
    }
  }

  // Tạo PIN lần đầu. newPin == null -> hệ thống cấp (trả về generatedPin đúng 1 lần).
  Future<Map<String, dynamic>> setupPin(String bookingId,
      {String? newPin}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.setupPin(bookingId),
        data: {if (newPin != null) 'newPin': newPin},
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception(message);
    }
  }

  // Đổi PIN: phải nhập đúng PIN hiện tại.
  Future<Map<String, dynamic>> updatePin(
      String bookingId, String currentPin, String newPin) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.updatePin(bookingId),
        data: {'currentPin': currentPin, 'newPin': newPin},
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception(message);
    }
  }

  // Quên PIN: xác minh bằng mật khẩu tài khoản. newPin == null -> hệ thống cấp.
  Future<Map<String, dynamic>> resetPin(String bookingId, String password,
      {String? newPin}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.resetPin(bookingId),
        data: {'password': password, if (newPin != null) 'newPin': newPin},
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception(message);
    }
  }

  // Mở khóa ngăn kho bằng PIN (mô phỏng - không có phần cứng khóa thật).
  Future<Map<String, dynamic>> unlockUnit(String bookingId, String pin) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.unlockUnit(bookingId),
        data: {'pin': pin},
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> lockUnit(String bookingId) async {
    try {
      final response = await _dio.post(ApiEndpoints.lockUnit(bookingId));
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to lock unit: $message');
    }
  }

  // Gia hạn thời gian thuê kho
  Future<Map<String, dynamic>> extendRental(
      String bookingId, int months) async {
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

  Future<Map<String, dynamic>?> getPendingExtensionPayment(
      String bookingId) async {
    try {
      final response =
          await _dio.get(ApiEndpoints.pendingExtensionPayment(bookingId));
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load pending extension payment: $message');
    }
  }

  // Hủy yêu cầu gia hạn đang chờ thanh toán (DELETE /{bookingId}/extend)
  Future<Map<String, dynamic>> cancelPendingExtension(String bookingId) async {
    try {
      final response = await _dio.delete(ApiEndpoints.extendRental(bookingId));
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to cancel extension: $message');
    }
  }

  // Khoản phí trễ hạn đang chờ thanh toán qua VNPay (null nếu không có)
  Future<Map<String, dynamic>?> getPendingOverduePayment(
      String bookingId) async {
    try {
      final response = await _dio.get(ApiEndpoints.overduePayment(bookingId));
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load overdue payment: $message');
    }
  }

  // Chỉ ĐỌC trạng thái giao dịch (PENDING/PAID/FAILED). Giao dịch chỉ thành PAID
  // khi VNPay gọi về server, khách không thể tự xác nhận.
  Future<Map<String, dynamic>> getPaymentStatus(String transactionId) async {
    try {
      final response =
          await _dio.get(ApiEndpoints.paymentStatus(transactionId));
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to get payment status: $message');
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

  String _formatLocalDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}'
        'T${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
