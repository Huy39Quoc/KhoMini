import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/network/http_client.dart';
import '../core/constants/api_endpoints.dart';

class AuthApiService {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await HttpClient.instance.post(
        ApiEndpoints.login,
        data: {
          'email':
              email, // Backend AuthServiceImpl đang nhận request.getEmail()
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final token = data['accessToken'] ?? data['token'];
        final role = data['role'] ?? data['roleName'] ?? 'CUSTOMER';

        if (token != null) {
          await _storage.write(key: 'jwt_token', value: token);
          await _storage.write(key: 'user_role', value: role);
        }
        return data;
      }
      throw Exception('Invalid response from server');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> register(
      String username, String email, String password, String fullName) async {
    try {
      final response = await HttpClient.instance.post(
        ApiEndpoints.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'fullName': fullName,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
