import 'package:dio/dio.dart';
import '../core/network/http_client.dart';
import '../core/constants/api_endpoints.dart';

class TicketApiService {
  Future<List<dynamic>> getTickets() async {
    try {
      final response = await HttpClient.instance.get(ApiEndpoints.tickets);
      if (response.statusCode == 200) {
        final data = response.data;
        return data is List ? data : (data['content'] ?? []);
      }
      throw Exception('Failed to load tickets');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Connection error');
    }
  }

  // Alias tương đương để khớp với ticket_list_screen.dart gọi getMyTickets()
  Future<List<dynamic>> getMyTickets() async {
    return getTickets();
  }

  Future<Map<String, dynamic>> getTicketDetail(String ticketId) async {
    try {
      final response =
          await HttpClient.instance.get(ApiEndpoints.ticketDetail(ticketId));
      if (response.statusCode == 200) {
        return response.data;
      }
      throw Exception('Failed to load ticket detail');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Ticket not found');
    }
  }

  // Nhận dạng tham số named arguments khớp với create_ticket_screen.dart
  Future<bool> createTicket({
    required String category,
    required String description,
    required String unitId,
  }) async {
    try {
      final response = await HttpClient.instance.post(
        ApiEndpoints.tickets,
        data: {
          'category': category,
          'description': description,
          'unitId': unitId,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to create ticket');
    }
  }
}
