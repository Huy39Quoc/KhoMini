import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../models/auth_model.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<AuthModel> login(String username, String password) async {
    final res = await _client.post(
      ApiConstants.login,
      body: {'username': username, 'password': password},
    );

    final authData = AuthModel.fromJson(res['data']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', authData.accessToken);
    await prefs.setString('refresh_token', authData.refreshToken);
    await prefs.setString('user_role', authData.role);
    await prefs.setString('user_name', authData.fullName);

    return authData;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
