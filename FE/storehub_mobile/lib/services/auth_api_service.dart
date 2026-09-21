import 'dart:convert';

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

      final data =
          body['data'] is Map ? Map<String, dynamic>.from(body['data']) : body;

      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];

      if (accessToken is String && accessToken.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', accessToken);
        if (refreshToken is String && refreshToken.isNotEmpty) {
          await prefs.setString('refresh_token', refreshToken);
        }
      }

      if (accessToken is String && accessToken.isNotEmpty) {
        final claims = _decodeJwtPayload(accessToken);
        final role = claims?['role'];
        if (role is String && role.isNotEmpty) {
          final userMap = data['user'];
          if (userMap is Map) {
            final merged = Map<String, dynamic>.from(userMap);
            merged['roleName'] = role;
            data['user'] = merged;
          }
        }
      }

      return data;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Login failed: $message');
    }
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      payload = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      return map is Map<String, dynamic> ? map : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String fullName,
    String phone,
  ) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'fullName': fullName,
          'phone': phone,
        },
      );
      return response.data is Map<String, dynamic>
          ? response.data
          : Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Registration failed: $message');
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.forgotPassword,
        data: {'email': email},
      );
      final body = response.data;
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
      return 'If this email exists, a reset link has been sent.';
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Request failed: $message');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post(
          ApiEndpoints.logout,
          data: {'refreshToken': refreshToken},
        );
      }
    } on DioException catch (_) {
    } finally {
      await prefs.remove('jwt_token');
      await prefs.remove('refresh_token');
    }
  }
}
