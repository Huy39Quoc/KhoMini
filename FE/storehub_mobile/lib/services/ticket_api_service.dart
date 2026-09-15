import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

class TicketApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<List<dynamic>> getMyTickets() async {
    try {
      final response = await _dio.get(ApiEndpoints.tickets);
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
      throw Exception('Failed to load tickets: $message');
    }
  }

  Future<void> createTicket(
      String category, String description, String? unitId) async {
    try {
      await _dio.post(
        ApiEndpoints.tickets,
        data: {
          'category': category,
          'description': description,
          'unitId': unitId,
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
      return response.data is Map<String, dynamic>
          ? response.data
          : Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load ticket detail: $message');
    }
  }
}
