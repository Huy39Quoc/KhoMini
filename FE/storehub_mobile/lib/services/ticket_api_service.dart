import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/paged_result.dart';

class TicketApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<PagedResult<Map<String, dynamic>>> getMyTickets({int page = 0}) async {
    try {
      final response = await _dio.get(ApiEndpoints.tickets,
          queryParameters: {'page': page, 'size': 20, 'sort': 'createdAt,desc'});
      return PagedResult.fromApi(response.data,
          (item) => Map<String, dynamic>.from(item as Map));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load tickets: $message');
    }
  }

  Future<void> createTicket(
    String category,
    String title,
    String description,
    String bookingId,
  ) async {
    try {
      await _dio.post(
        ApiEndpoints.tickets,
        data: {
          'category': category,
          'title': title,
          'description': description,
          'bookingId': bookingId,
        },
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to create ticket: $message');
    }
  }

  Future<Map<String, dynamic>> getTicketDetail(String ticketId) async {
    try {
      final response = await _dio.get(ApiEndpoints.ticketDetail(ticketId));
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data']);
      }
      return data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load ticket detail: $message');
    }
  }
}
