import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/ticket_model.dart';

/// Kết nối StaffTicketController: nhân viên cơ sở xem ticket của cơ sở mình,
/// tự nhận xử lý và cập nhật trạng thái (OPEN -> IN_PROGRESS -> RESOLVED -> CLOSED).
class StaffTicketApiService {
  final Dio _dio = HttpClient.instance.dio;

  Exception _err(DioException e, String action) {
    final data = e.response?.data;
    final message = (data is Map ? data['message'] : null) ?? e.message;
    return Exception('Failed to $action: $message');
  }

  TicketModel _toTicket(dynamic data) {
    final body = (data is Map && data['data'] is Map) ? data['data'] : data;
    return TicketModel.fromJson(Map<String, dynamic>.from(body as Map));
  }

  /// GET /staff/tickets?facilityId=... (phân trang, mới nhất trước)
  Future<List<TicketModel>> getFacilityTickets(String facilityId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.staffTickets,
        queryParameters: {'facilityId': facilityId, 'size': 100},
      );
      final data = response.data;
      List<dynamic> content = [];
      if (data is Map && data['data'] is Map && data['data']['content'] is List) {
        content = data['data']['content'];
      } else if (data is Map && data['content'] is List) {
        content = data['content'];
      }
      return content
          .map((e) => TicketModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (e) {
      throw _err(e, 'load facility tickets');
    }
  }

  /// POST /staff/tickets/{id}/assign-to-me?facilityId=...
  Future<TicketModel> assignToMe(String facilityId, String ticketId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.staffTicketAssign(ticketId),
        queryParameters: {'facilityId': facilityId},
      );
      return _toTicket(response.data);
    } on DioException catch (e) {
      throw _err(e, 'assign the ticket');
    }
  }

  /// PATCH /staff/tickets/{id}/status?facilityId=...
  /// [resolutionNote] bắt buộc khi chuyển sang RESOLVED hoặc CLOSED.
  Future<TicketModel> updateStatus(
    String facilityId,
    String ticketId,
    String status, {
    String? resolutionNote,
  }) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.staffTicketStatus(ticketId),
        queryParameters: {'facilityId': facilityId},
        data: {
          'status': status,
          if (resolutionNote != null && resolutionNote.trim().isNotEmpty)
            'resolutionNote': resolutionNote.trim(),
        },
      );
      return _toTicket(response.data);
    } on DioException catch (e) {
      throw _err(e, 'update the ticket');
    }
  }
}
