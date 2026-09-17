import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';

class AdminApiService {
  final Dio _dio = HttpClient.instance.dio;

  // BE (GET /users) trả về danh sách có phân trang: { data: { content: [...] } }.
  // Trước đây chỉ kiểm tra data['data'] is List (luôn false) nên danh sách
  // người dùng luôn hiện trống.
  // BE (GET /users) chỉ trả về 1 trang (mặc định 10 bản ghi). Trước đây
  // lấy .length của trang đó làm "tổng số user" là sai; endpoint có sẵn
  // "totalElements" trong phần phân trang nên đọc trực tiếp từ đó.
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

  Future<List<dynamic>> getUsers() async {
    try {
      final response = await _dio.get(ApiEndpoints.users);
      return _extractList(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load users: $message');
    }
  }

  // BE (GET /roles) cũng trả về dữ liệu phân trang tương tự.
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

  // BE định nghĩa endpoint này là PATCH, trước đây FE gọi bằng PUT -> lỗi 405.
  Future<void> toggleUserActive(String userId) async {
    try {
      await _dio.patch(ApiEndpoints.toggleUserActive(userId));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to toggle user status: $message');
    }
  }

  // Trước đây gọi PUT /users/{id}/role - endpoint này KHÔNG tồn tại trên BE
  // (luôn lỗi 404). BE chỉ hỗ trợ đổi role thông qua PUT /users/{id} với
  // UserUpdateRequest {roleId, phone, ...}, trong đó "phone" là bắt buộc
  // nên phải truyền lại số điện thoại hiện tại của user.
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
