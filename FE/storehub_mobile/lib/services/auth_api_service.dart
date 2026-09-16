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

  // BE (RegisterRequest) bắt buộc cả username và phone (số VN hợp lệ),
  // trước đây 2 trường này bị thiếu -> đăng ký luôn thất bại.
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

  // BE (/auth/logout) yêu cầu bắt buộc refreshToken trong body.
  // Trước đây không gửi gì -> BE trả lỗi 400 và exception này làm nút
  // "Sign Out" không bao giờ đưa được người dùng về màn hình login.
  // Giờ luôn dọn sạch token cục bộ (dù server lỗi/refresh token đã hết hạn)
  // để người dùng chắc chắn thoát được khỏi phiên đăng nhập.
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
      // Bỏ qua lỗi từ server (vd token đã bị thu hồi/hết hạn) - vẫn đăng
      // xuất cục bộ để không kẹt người dùng lại trong app.
    } finally {
      await prefs.remove('jwt_token');
      await prefs.remove('refresh_token');
    }
  }
}
