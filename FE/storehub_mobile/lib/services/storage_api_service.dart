import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../mappers/facility_operations_mapper.dart';
import '../models/facility_operations_models.dart';

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
      throw Exception('Không tải được kho đang thuê: $message');
    }
  }

  Future<List<dynamic>> getAwaitingHandover() async {
    try {
      final response = await _dio.get(ApiEndpoints.awaitingHandover);
      final body = response.data;
      return body is Map && body['data'] is List
          ? List<dynamic>.from(body['data'])
          : <dynamic>[];
    } on DioException catch (e) {
      final body = e.response?.data;
      throw Exception('Không tải được các đơn chờ nhận kho: '
          '${body is Map ? body['message'] : e.message}');
    }
  }

  Future<Map<String, dynamic>> issueGatePass(String bookingId) async {
    try {
      final response = await _dio.post(ApiEndpoints.gatePass(bookingId));
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final body = e.response?.data;
      throw Exception('Không thể tạo mã QR cổng: '
          '${body is Map ? body['message'] : e.message}');
    }
  }

  // Lấy trạng thái smart access (đã có PIN chưa, đang khóa/mở). Server không trả PIN đã lưu.
  Future<Map<String, dynamic>> getSmartAccess(String bookingId) async {
    try {
      final response = await _dio.get(ApiEndpoints.smartAccess(bookingId));
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không lấy được thông tin khóa thông minh: $message');
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
      throw Exception('Không thể khóa ngăn kho: $message');
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
      throw Exception('Không thể gia hạn: $message');
    }
  }

  // Gửi yêu cầu trả kho (checkout)
  Future<Map<String, dynamic>> checkoutRental(
    String bookingId,
    DateTime scheduledReturnTime, {
    String? notes,
    String? bankCode,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.checkoutRental(bookingId),
        data: {
          'scheduledReturnTime': _formatLocalDateTime(scheduledReturnTime),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          if (bankCode != null && bankCode.trim().isNotEmpty)
            'bankCode': bankCode.trim(),
          if (bankAccountNumber != null && bankAccountNumber.trim().isNotEmpty)
            'bankAccountNumber': bankAccountNumber.trim(),
          if (bankAccountName != null && bankAccountName.trim().isNotEmpty)
            'bankAccountName': bankAccountName.trim(),
        },
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể gửi yêu cầu trả kho: $message');
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
      throw Exception('Không tải được khoản gia hạn đang chờ: $message');
    }
  }

  // Hủy yêu cầu gia hạn đang chờ thanh toán (DELETE /{bookingId}/extend)
  Future<Map<String, dynamic>> cancelPendingExtension(String bookingId) async {
    try {
      final response = await _dio.delete(ApiEndpoints.extendRental(bookingId));
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể hủy gia hạn: $message');
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
      throw Exception('Không tải được phí trễ hạn: $message');
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
      throw Exception('Không lấy được trạng thái thanh toán: $message');
    }
  }

  Future<List<HandoverRecordModel>> getCustomerHandoverRecords(String bookingId) async {
    try {
      final response = await _dio.get(ApiEndpoints.customerHandoverRecords(bookingId));
      final data = response.data;
      final list = (data is Map && data['data'] is List) ? data['data'] as List : [];
      return list
          .map((e) => FacilityOperationsMapper.handoverRecordFromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được biên bản bàn giao: $message');
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
