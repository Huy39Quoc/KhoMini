import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

class BookingApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<Map<String, dynamic>> createBooking({
    required String facilityId,
    required String unitTypeId,
    required DateTime startDate,
    required int rentalMonths,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.bookings,
        data: {
          'facilityId': facilityId,
          'unitTypeId': unitTypeId,
          'startDate': _formatLocalDate(startDate),
          'rentalMonths': rentalMonths,
        },
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to create booking: $message');
    }
  }

  Future<void> cancelBooking({required String bookingId}) async {
    try {
      await _dio.delete(ApiEndpoints.cancelBooking(bookingId));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to cancel booking: $message');
    }
  }

  Future<void> joinWaitlist({
    required String facilityId,
    required String unitTypeId,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.waitlist,
        queryParameters: {
          'facilityId': facilityId,
          'unitTypeId': unitTypeId,
        },
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to join waitlist: $message');
    }
  }

  Future<Map<String, dynamic>> initiatePayment({
    required String bookingId,
    String paymentType = 'DEPOSIT',
    String? paymentMethod,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.paymentInitiate,
        data: {
          'bookingId': bookingId,
          'paymentType': paymentType,
          if (paymentMethod != null) 'paymentMethod': paymentMethod,
        },
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to initiate payment: $message');
    }
  }

  Future<Map<String, dynamic>> confirmPayment({
    required String transactionId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.paymentConfirm,
        data: {'transactionId': transactionId},
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to confirm payment: $message');
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

  String _formatLocalDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}';
  }
}
