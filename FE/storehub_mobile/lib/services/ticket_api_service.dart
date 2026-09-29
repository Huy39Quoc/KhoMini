import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

class TicketApiService {
  final Dio _dio = HttpClient.instance.dio;

  // BE trả về danh sách có phân trang: { data: { content: [...], page, ... } },
  // trước đây chỉ kiểm tra data['data'] is List (luôn false vì đó là Map)
  // nên màn hình danh sách ticket luôn hiện trống dù đã có ticket.
  Future<List<dynamic>> getMyTickets() async {
    try {
      final response = await _dio.get(ApiEndpoints.tickets);
      final data = response.data;
      if (data is List) {
        return data;
      } else if (data is Map) {
        if (data['data'] is Map && data['data']['content'] is List) {
          return data['data']['content'];
        } else if (data['content'] is List) {
          return data['content'];
        } else if (data['result'] is List) {
          return data['result'];
        } else if (data['data'] is List) {
          return data['data'];
        }
      }
      return [];
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load tickets: $message');
    }
  }

  // BE (CreateTicketRequest) bắt buộc "title" (trước đây không gửi) và
  // dùng field "bookingId" chứ không phải "unitId".
  Future<void> createTicket(
    String category,
    String title,
    String description,
    String? bookingId,
  ) async {
    try {
      await _dio.post(
        ApiEndpoints.tickets,
        data: {
          'category': category,
          'title': title,
          'description': description,
          if (bookingId != null && bookingId.isNotEmpty)
            'bookingId': bookingId,
        },
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to create ticket: $message');
    }
  }

  // Trước đây hàm này trả nguyên cả bọc {success, message, data: {...}}
  // thay vì bóc "data" ra - y hệt lỗi từng gặp ở getSmartAccess. Đây cũng
  // là lý do màn hình chi tiết ticket chưa từng được nối dù API đã có sẵn.
  Future<Map<String, dynamic>> getTicketDetail(String ticketId) async {
    try {
      final response = await _dio.get(ApiEndpoints.ticketDetail(ticketId));
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data']);
      }
      return data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load ticket detail: $message');
    }
  }
}
