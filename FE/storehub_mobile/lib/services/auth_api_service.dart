import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

class AuthApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );

      final body = response.data is Map<String, dynamic>
          ? response.data
          : Map<String, dynamic>.from(response.data);

      // BE trả về dạng { success, message, data: { accessToken, refreshToken, user } }
      final data =
          body['data'] is Map ? Map<String, dynamic>.from(body['data']) : body;

      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];

      // Lưu token để HttpClient tự đính Authorization: Bearer ... cho các request sau.
      // Trước đây bước này bị thiếu -> mọi API cần đăng nhập đều gọi mà không có token.
      if (accessToken is String && accessToken.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', accessToken);
        if (refreshToken is String && refreshToken.isNotEmpty) {
          await prefs.setString('refresh_token', refreshToken);
        }
      }

      return data;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Login failed: $message');
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: {'email': email, 'password': password, 'fullName': fullName},
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Registration failed: $message');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Logout failed: $message');
    }
  }
}
