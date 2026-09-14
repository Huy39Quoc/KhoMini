import '../core/constants/api_constants.dart';
import '../models/my_unit_model.dart';
import '../models/smart_access_model.dart';
import '../models/ticket_model.dart';
import 'api_client.dart';

class CustomerStorageService {
  final ApiClient _client = ApiClient();

  Future<List<MyUnitModel>> getMyRentedUnits() async {
    final res = await _client.get(ApiConstants.myUnits);
    final List<dynamic> list = res['data'] ?? [];
    return list.map((e) => MyUnitModel.fromJson(e)).toList();
  }

  Future<SmartAccessModel> getSmartAccess(int bookingId) async {
    final res = await _client.get(ApiConstants.smartAccess(bookingId));
    return SmartAccessModel.fromJson(res['data']);
  }

  Future<SmartAccessModel> updatePin(int bookingId, String newPin) async {
    final res = await _client.put(
      ApiConstants.updatePin(bookingId),
      body: {'newPin': newPin},
    );
    return SmartAccessModel.fromJson(res['data']);
  }

  Future<void> extendRental(int bookingId, int extraMonths) async {
    await _client.post(
      ApiConstants.extendRental(bookingId),
      body: {'extraMonths': extraMonths},
    );
  }

  Future<void> requestCheckout(
      int bookingId, String scheduledReturnTime, String? notes) async {
    await _client.post(
      ApiConstants.requestCheckout(bookingId),
      body: {'scheduledReturnTime': scheduledReturnTime, 'notes': notes},
    );
  }

  Future<List<TicketModel>> getMyTickets() async {
    final res = await _client.get(ApiConstants.tickets);
    final List<dynamic> list = res['data']['items'] ?? [];
    return list.map((e) => TicketModel.fromJson(e)).toList();
  }

  Future<void> createTicket(
      String category, String title, String description, int? bookingId) async {
    await _client.post(
      ApiConstants.tickets,
      body: {
        'category': category,
        'title': title,
        'description': description,
        'bookingId': bookingId,
      },
    );
  }
}
