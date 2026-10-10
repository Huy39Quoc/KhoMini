import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/paged_result.dart';

class AdminApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<int> getTotalUsersCount() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.users,
        queryParameters: {'page': 0, 'size': 1},
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final total = data['data']['totalElements'];
        if (total is num) return total.toInt();
      }
      return 0;
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load user count: $message');
    }
  }

  Future<({int total, int active})> getUserSummary() async {
    try {
      final response = await _dio.get(ApiEndpoints.usersSummary);
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final d = data['data'] as Map;
        final total = d['totalUsers'];
        final active = d['activeUsers'];
        return (
          total: total is num ? total.toInt() : 0,
          active: active is num ? active.toInt() : 0,
        );
      }
      return (total: 0, active: 0);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load user count: $message');
    }
  }

  Future<List<dynamic>> getUsers() async {
    final all = <dynamic>[];
    var page = 0;
    while (true) {
      final batch = await getUsersPage(page: page++);
      all.addAll(batch.content);
      if (batch.last) return all;
    }
  }

  Future<PagedResult<Map<String, dynamic>>> getUsersPage({int page = 0,
      String search = '', bool? isActive}) async {
    try {
      final response = await _dio.get(ApiEndpoints.users, queryParameters: {
        'page': page, 'size': 20,
        if (search.isNotEmpty) 'search': search,
        if (isActive != null) 'isActive': isActive,
      });
      return PagedResult.fromApi(response.data,
          (item) => Map<String, dynamic>.from(item as Map));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load users: $message');
    }
  }

  Future<List<dynamic>> getRoles() async {
    try {
      final response = await _dio.get(ApiEndpoints.roles);
      return _extractList(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load roles: $message');
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      if (data['data'] is Map && data['data']['content'] is List) {
        return data['data']['content'];
      } else if (data['content'] is List) {
        return data['content'];
      } else if (data['result'] is List) {
        return data['result'];
      } else if (data['data'] is List) {
        return data['data'];
      }
    }
    return [];
  }

  Future<void> toggleUserActive(String userId) async {
    try {
      await _dio.patch(ApiEndpoints.toggleUserActive(userId));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to toggle user status: $message');
    }
  }

  Future<List<dynamic>> getPermissions() async {
    try {
      final permissions = <dynamic>[];
      var page = 0;
      while (true) {
        final response = await _dio.get(ApiEndpoints.permissions,
            queryParameters: {'page': page++, 'size': 50});
        final batch = PagedResult.fromApi(response.data,
            (item) => Map<String, dynamic>.from(item as Map));
        permissions.addAll(batch.content);
        if (batch.last) return permissions;
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load permissions: $message');
    }
  }

  Future<List<dynamic>> getRolePermissionsByRole(String roleId) async {
    try {
      final response =
          await _dio.get(ApiEndpoints.rolePermissionsByRole(roleId));
      final data = response.data;
      if (data is Map && data['data'] is List) return data['data'];
      if (data is List) return data;
      return [];
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load role permissions: $message');
    }
  }

  Future<void> bulkAssignPermissions(
      String roleId, List<String> permissionIds) async {
    try {
      await _dio.post(
        ApiEndpoints.rolePermissionsBulkAssign,
        data: {
          'roleId': roleId,
          'permissionIds': permissionIds,
        },
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to update role permissions: $message');
    }
  }

  Future<void> revokeRolePermission(String rolePermissionId) async {
    try {
      await _dio.delete(ApiEndpoints.rolePermissionDetail(rolePermissionId));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to revoke permission: $message');
    }
  }

  Future<void> createRole(String name, String? description) async {
    try {
      await _dio.post(
        ApiEndpoints.roles,
        data: {
          'name': name,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to create role: $message');
    }
  }

  Future<void> updateUserRole(
    String userId,
    String roleId,
    String currentPhone,
  ) async {
    try {
      await _dio.put(
        ApiEndpoints.userDetail(userId),
        data: {
          'roleId': roleId,
          'phone': currentPhone,
        },
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to assign role: $message');
    }
  }
}
