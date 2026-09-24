import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

/// Wires the real BookingController / PaymentController endpoints.
/// Previously payment_screen.dart faked the whole flow client-side
/// (Future.delayed + a random booking code); this service actually
/// creates the booking and payment records on the BE.
class BookingApiService {
  final Dio _dio = HttpClient.instance.dio;

  /// POST /bookings - creates a real booking (status PENDING_PAYMENT).
  /// The BE recalculates the price itself from unitTypeId/startDate/
  /// rentalMonths (same PricingService used by /pricing/quote), and picks
  /// an available StorageUnit for that facility + unit type.
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

  /// POST /payments/initiate - creates a PENDING payment for the booking
  /// and returns a real transactionId + a real VietQR image URL.
  /// paymentType matches com.storehub.enums.PaymentType: DEPOSIT,
  /// RENTAL_FEE, EXTRA_CHARGE.
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

  /// POST /payments/confirm - marks the payment PAID, the booking
  /// CONFIRMED, and the storage unit OCCUPIED on the BE.
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

  /// DELETE /bookings/{id} - cancels a PENDING_PAYMENT booking, releasing
  /// the reserved unit back to AVAILABLE and notifying the waitlist.
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _dio.delete(ApiEndpoints.bookingDetail(bookingId));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to cancel booking: $message');
    }
  }

  /// POST /waitlist?facilityId=...&unitTypeId=... - join the waitlist for a
  /// unit type that currently has no AVAILABLE units at a facility.
  Future<String> joinWaitlist({
    required String facilityId,
    required String unitTypeId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.waitlist,
        queryParameters: {'facilityId': facilityId, 'unitTypeId': unitTypeId},
      );
      final body = response.data;
      if (body is Map && body['message'] is String) return body['message'] as String;
      return "You've been added to the waitlist.";
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to join waitlist: $message');
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
