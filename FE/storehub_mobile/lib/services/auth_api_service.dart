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

      // BE's UserResponse (data['user']) does NOT include the user's role at
      // all (UserMapper explicitly ignores it), so every account used to be
      // routed to the Customer UI regardless of its real role. The access
      // token itself DOES carry a "role" claim (see JwtServiceImpl on the
      // BE), so we decode it here and merge it into the user map. This is a
      // FE-only fix; nothing on the BE is touched.
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

  /// Decodes the middle (payload) segment of a JWT and returns its claims
  /// as a Map. Returns null if the token is malformed. This does NOT verify
  /// the token's signature - it is only used to read non-sensitive display
  /// claims (role, userId, fullName) already trusted because the token was
  /// just issued by our own backend over HTTPS.
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

  // BE always responds with a generic success message regardless of
  // whether the email exists, so we simply surface that message to the UI.
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
