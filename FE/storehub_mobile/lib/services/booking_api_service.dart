import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

/// Wires the real BookingController / PaymentController endpoints.
/// Previously payment_screen.dart faked the whole flow client-side
/// (Future.delayed + a random booking code); this service actually
/// creates the booking and payment records on the BE.
class BookingApiService {
  final HttpClient _http = HttpClient.instance;

  Future<List<Map<String, dynamic>>> getPayableBookings() async {
    try {
      final response = await _http.get(ApiEndpoints.myPendingBookings);
      final body = response.data;
      final list = body is Map ? body['data'] : null;
      if (list is! List) throw const FormatException('Danh sách đơn không hợp lệ');
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on ApiException catch (e) {
      final body = e.response?.data;
      final message = body is Map ? body['message'] : e.message;
      throw Exception('Không tải được các đơn đang chờ: $message');
    }
  }

  /// POST /bookings - creates a real booking (status PENDING_PAYMENT).
  /// The BE recalculates the price itself from unitTypeId/startDate/
  /// rentalMonths (same PricingService used by /pricing/quote), and picks
  /// an available StorageUnit for that facility + unit type.
  Future<Map<String, dynamic>> createBooking({
    required String facilityId,
    required String unitTypeId,
    required DateTime startDate,
    required String checkInTime,
    required int rentalMonths,
    bool prohibitedItemsConfirmed = true,
    bool termsConfirmed = true,
    String? termsVersion,
  }) async {
    try {
      final response = await _http.post(
        ApiEndpoints.bookings,
        data: {
          'facilityId': facilityId,
          'unitTypeId': unitTypeId,
          'startDate': _formatLocalDate(startDate),
          'checkInTime': checkInTime,
          'rentalMonths': rentalMonths,
          'prohibitedItemsConfirmed': prohibitedItemsConfirmed,
          'termsConfirmed': termsConfirmed,
          if (termsVersion != null && termsVersion.isNotEmpty)
            'termsVersion': termsVersion,
        },
      );
      return _unwrapMap(response.data);
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể tạo đơn đặt kho: $message');
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
      final response = await _http.post(
        ApiEndpoints.paymentInitiate,
        data: {
          'bookingId': bookingId,
          'paymentType': paymentType,
          if (paymentMethod != null) 'paymentMethod': paymentMethod,
        },
      );
      return _unwrapMap(response.data);
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể khởi tạo thanh toán: $message');
    }
  }

  /// GET /payments/{transactionId}/status - read-only. The payment becomes PAID
  /// only when VNPay calls the server back; the client cannot confirm it.
  Future<Map<String, dynamic>> getPaymentStatus({
    required String transactionId,
  }) async {
    try {
      final response =
          await _http.get(ApiEndpoints.paymentStatus(transactionId));
      return _unwrapMap(response.data);
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không lấy được trạng thái thanh toán: $message');
    }
  }

  /// DELETE /bookings/{id} - cancels a PENDING_PAYMENT booking, releasing
  /// the reserved unit back to AVAILABLE and notifying the waitlist.
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _http.delete(ApiEndpoints.bookingDetail(bookingId));
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể hủy đơn: $message');
    }
  }

  /// POST /waitlist?facilityId=...&unitTypeId=... - join the waitlist for a
  /// unit type that currently has no AVAILABLE units at a facility.
  Future<String> joinWaitlist({
    required String facilityId,
    required String unitTypeId,
  }) async {
    try {
      final response = await _http.post(
        ApiEndpoints.waitlist,
        queryParameters: {'facilityId': facilityId, 'unitTypeId': unitTypeId},
      );
      final body = response.data;
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
      return "Bạn đã được thêm vào danh sách chờ.";
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể vào danh sách chờ: $message');
    }
  }

  Future<List<Map<String, dynamic>>> getMyWaitlist() async {
    final response = await _http.get('${ApiEndpoints.waitlist}/mine');
    final data = response.data;
    final entries = data is Map ? data['data'] : null;
    if (entries is! List) throw const FormatException('Dữ liệu danh sách chờ không hợp lệ');
    return entries.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> leaveWaitlist(String id) async {
    await _http.delete('${ApiEndpoints.waitlist}/$id');
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
