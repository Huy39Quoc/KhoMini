import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/auth_model.dart';

class AuthApiService {
  final HttpClient _http = HttpClient();

  Future<AuthModel> login(String username, String password) async {
    final res = await _http.post(
      ApiEndpoints.login,
      body: {'username': username, 'password': password},
    );

    final data = AuthModel.fromJson(res['data']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data.accessToken);
    await prefs.setString('refresh_token', data.refreshToken);
    await prefs.setString('user_role', data.role);
    await prefs.setString('user_name', data.fullName);
    return data;
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    await _http.post(
      ApiEndpoints.register,
      body: {
        'username': username,
        'email': email,
        'password': password,
        'fullName': fullName,
        'phone': phone,
      },
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
