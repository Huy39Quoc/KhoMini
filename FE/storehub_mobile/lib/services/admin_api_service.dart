import 'package:dio/dio.dart';
import '../core/network/http_client.dart';
import '../core/constants/api_endpoints.dart';

class AdminApiService {
  Future<List<dynamic>> getUsers() async {
    try {
      final response = await HttpClient.instance.get(ApiEndpoints.users);
      if (response.statusCode == 200) {
        final data = response.data;
        return data is List ? data : (data['content'] ?? []);
      }
      throw Exception('Failed to fetch user list');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Connection error');
    }
  }

  // Hàm assignRole phục vụ cho user_management_screen.dart
  Future<bool> assignRole(String userId, String roleName) async {
    try {
      final response = await HttpClient.instance.put(
        ApiEndpoints.userRole(userId),
        data: {'role': roleName},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to assign role');
    }
  }

  Future<bool> updateUserStatus(String userId, bool active) async {
    try {
      final response = await HttpClient.instance.put(
        '${ApiEndpoints.users}/$userId/status',
        data: {'active': active},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(
          e.response?.data['message'] ?? 'Failed to update user status');
    }
  }
}
