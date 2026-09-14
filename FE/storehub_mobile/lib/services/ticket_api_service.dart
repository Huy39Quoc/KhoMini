import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/ticket_model.dart';

class TicketApiService {
  final HttpClient _http = HttpClient();

  Future<List<TicketModel>> getMyTickets() async {
    final res = await _http.get(ApiEndpoints.tickets);
    final List<dynamic> list =
        res['data']?['content'] ?? res['data']?['items'] ?? [];
    return list.map((e) => TicketModel.fromJson(e)).toList();
  }

  Future<void> createTicket(String category, String title, String description,
      String? bookingId) async {
    await _http.post(
      ApiEndpoints.tickets,
      body: {
        'category': category,
        'title': title,
        'description': description,
        'bookingId': bookingId,
      },
    );
  }
}
