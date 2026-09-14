import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class AdminService {
  final ApiClient _client = ApiClient();

  Future<List<UserModel>> getUsers() async {
    final res = await _client.get(ApiConstants.users);
    final List<dynamic> list = res['data']['items'] ?? res['data'] ?? [];
    return list.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<void> assignRole(String userId, String roleName) async {
    await _client.put(
      '${ApiConstants.users}/$userId/role',
      body: {'role': roleName},
    );
  }
}
