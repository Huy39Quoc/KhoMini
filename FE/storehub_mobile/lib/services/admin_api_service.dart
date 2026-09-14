import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/user_model.dart';

class AdminApiService {
  final HttpClient _http = HttpClient();

  Future<List<UserModel>> getUsers() async {
    final res = await _http.get(ApiEndpoints.users);
    final List<dynamic> list =
        res['data']?['content'] ?? res['data']?['items'] ?? res['data'] ?? [];
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<void> assignRole(String userId, String roleName) async {
    await _http.put(
      ApiEndpoints.userRole(userId),
      body: {'role': roleName},
    );
  }
}
