import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/my_unit_model.dart';
import '../models/smart_access_model.dart';

class StorageApiService {
  final HttpClient _http = HttpClient();

  Future<List<MyUnitModel>> getMyRentedUnits() async {
    final res = await _http.get(ApiEndpoints.myUnits);
    final List<dynamic> list = res['data'] ?? [];
    return list.map((e) => MyUnitModel.fromJson(e)).toList();
  }

  Future<SmartAccessModel> getSmartAccess(String bookingId) async {
    final res = await _http.get(ApiEndpoints.smartAccess(bookingId));
    return SmartAccessModel.fromJson(res['data']);
  }

  Future<SmartAccessModel> updatePin(String bookingId, String newPin) async {
    final res = await _http.put(
      ApiEndpoints.updatePin(bookingId),
      body: {'newPin': newPin},
    );
    return SmartAccessModel.fromJson(res['data']);
  }

  Future<void> extendRental(String bookingId, int extraMonths) async {
    await _http.post(
      ApiEndpoints.extendRental(bookingId),
      body: {'extraMonths': extraMonths},
    );
  }

  Future<void> requestCheckout(
      String bookingId, String scheduledReturnTime, String? notes) async {
    await _http.post(
      ApiEndpoints.requestCheckout(bookingId),
      body: {'scheduledReturnTime': scheduledReturnTime, 'notes': notes},
    );
  }
}
