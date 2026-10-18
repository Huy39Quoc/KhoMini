import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/paged_result.dart';

class AdminApiService {
  final HttpClient _http = HttpClient.instance;

  Future<int> getTotalUsersCount() async {
    try {
      final response = await _http.get(
        ApiEndpoints.users,
        queryParameters: {'page': 0, 'size': 1},
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final total = data['data']['totalElements'];
        if (total is num) return total.toInt();
      }
      return 0;
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được số lượng người dùng: $message');
    }
  }

  Future<({int total, int active})> getUserSummary() async {
    try {
      final response = await _http.get(ApiEndpoints.usersSummary);
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
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được số lượng người dùng: $message');
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
      String search = '', bool? isActive, String? roleName}) async {
    try {
      final response = await _http.get(ApiEndpoints.users, queryParameters: {
        'page': page, 'size': 20,
        // Sắp xếp theo vai trò để danh sách được nhóm theo từng vai trò
        'sortBy': 'role', 'sortDir': 'asc',
        if (roleName != null && roleName.isNotEmpty) 'roleName': roleName,
        if (search.isNotEmpty) 'search': search,
        if (isActive != null) 'isActive': isActive,
      });
      return PagedResult.fromApi(response.data,
          (item) => Map<String, dynamic>.from(item as Map));
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được người dùng: $message');
    }
  }

  Future<List<dynamic>> getRoles() async {
    try {
      final response = await _http.get(ApiEndpoints.roles);
      return _extractList(response.data);
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được danh sách vai trò: $message');
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
      await _http.patch(ApiEndpoints.toggleUserActive(userId));
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể đổi trạng thái người dùng: $message');
    }
  }

  Future<List<dynamic>> getPermissions() async {
    try {
      final permissions = <dynamic>[];
      var page = 0;
      while (true) {
        final response = await _http.get(ApiEndpoints.permissions,
            queryParameters: {'page': page++, 'size': 50});
        final batch = PagedResult.fromApi(response.data,
            (item) => Map<String, dynamic>.from(item as Map));
        permissions.addAll(batch.content);
        if (batch.last) return permissions;
      }
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được danh sách quyền: $message');
    }
  }

  Future<List<dynamic>> getRolePermissionsByRole(String roleId) async {
    try {
      final response =
          await _http.get(ApiEndpoints.rolePermissionsByRole(roleId));
      final data = response.data;
      if (data is Map && data['data'] is List) return data['data'];
      if (data is List) return data;
      return [];
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được quyền của vai trò: $message');
    }
  }

  Future<void> bulkAssignPermissions(
      String roleId, List<String> permissionIds) async {
    try {
      await _http.post(
        ApiEndpoints.rolePermissionsBulkAssign,
        data: {
          'roleId': roleId,
          'permissionIds': permissionIds,
        },
      );
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể cập nhật quyền của vai trò: $message');
    }
  }

  Future<void> revokeRolePermission(String rolePermissionId) async {
    try {
      await _http.delete(ApiEndpoints.rolePermissionDetail(rolePermissionId));
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể thu hồi quyền: $message');
    }
  }

  Future<void> updateUserRole(
    String userId,
    String roleId,
    String currentPhone,
  ) async {
    try {
      await _http.put(
        ApiEndpoints.userDetail(userId),
        data: {
          'roleId': roleId,
          'phone': currentPhone,
        },
      );
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể gán vai trò: $message');
    }
  }

  // ---------------------------------------------------------------------------
  // Quản lý tài khoản người dùng
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getUserDetail(String userId) async {
    try {
      final response = await _http.get(ApiEndpoints.userDetail(userId));
      return _unwrap(response.data);
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được thông tin người dùng: $message');
    }
  }

  Future<void> createUser({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? roleId,
  }) async {
    try {
      await _http.post(
        ApiEndpoints.users,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'fullName': fullName,
          'phone': phone,
          if (roleId != null && roleId.isNotEmpty) 'roleId': roleId,
        },
      );
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể tạo người dùng: $message');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _http.delete(ApiEndpoints.userDetail(userId));
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('$message');
    }
  }

  // ---------------------------------------------------------------------------
  // Vai trò & quyền: xem chi tiết, sửa mô tả (5 vai trò và danh sách quyền là cố định)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getRoleDetail(String roleId) async {
    try {
      final response = await _http.get(ApiEndpoints.roleDetail(roleId));
      return _unwrap(response.data);
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được chi tiết vai trò: $message');
    }
  }

  Future<void> updateRoleDescription(
      Map<String, dynamic> role, String description) async {
    try {
      await _http.put(
        ApiEndpoints.roleDetail(role['id'].toString()),
        data: {
          'name': role['name'],
          'description': description.trim(),
          'isActive': role['isActive'] != false,
        },
      );
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể cập nhật vai trò: $message');
    }
  }

  Future<Map<String, dynamic>> getPermissionDetail(String permissionId) async {
    try {
      final response =
          await _http.get(ApiEndpoints.permissionDetail(permissionId));
      return _unwrap(response.data);
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được chi tiết quyền: $message');
    }
  }

  Future<void> updatePermissionDescription(
      Map<String, dynamic> permission, String description) async {
    try {
      await _http.put(
        ApiEndpoints.permissionDetail(permission['id'].toString()),
        data: {
          'name': permission['name'],
          'permissionGroup': permission['permissionGroup'],
          'description': description.trim(),
          'isActive': permission['isActive'] != false,
        },
      );
    } on ApiException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể cập nhật quyền: $message');
    }
  }
}
