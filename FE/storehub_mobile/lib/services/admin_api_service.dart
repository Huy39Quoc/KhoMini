import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

class AdminApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<List<dynamic>> getUsers() async {
    try {
      final response = await _dio.get(ApiEndpoints.users);
      if (response.data is List) {
        return response.data;
      } else if (response.data['result'] is List) {
        return response.data['result'];
      } else if (response.data['data'] is List) {
        return response.data['data'];
      }
      return [];
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load users: $message');
    }
  }

  Future<void> toggleUserActive(String userId) async {
    try {
      await _dio.put(ApiEndpoints.toggleUserActive(userId));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to toggle user status: $message');
    }
  }

  Future<void> assignRole(String userId, String roleName) async {
    try {
      await _dio.put(
        '${ApiEndpoints.users}/$userId/role',
        data: {'role': roleName},
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to assign role: $message');
    }
  }
}
