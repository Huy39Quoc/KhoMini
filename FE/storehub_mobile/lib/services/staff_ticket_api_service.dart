
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../mappers/staff_ticket_mapper.dart';
import '../models/staff_ticket_model.dart';
import '../models/paged_result.dart';

class StaffTicketApiService {
  final HttpClient _http = HttpClient.instance;

  Future<PagedResult<StaffTicketModel>> getFacilityTickets(
    String facilityId, {int page = 0}
  ) async {
    try {
      final response = await _http.get(
        ApiEndpoints.staffTickets,
        queryParameters: {
          'facilityId': facilityId,
          'page': page,
          'size': 20,
          'sort': 'createdAt,desc',
        },
      );

      return PagedResult.fromApi(response.data, (item) =>
          StaffTicketMapper.fromJson(StaffTicketMapper.asJsonMap(item)));
    } on ApiException catch (error) {
      throw _error(error, 'tải yêu cầu hỗ trợ của cơ sở');
    }
  }

  Future<StaffTicketModel> assignToMe({
    required String facilityId,
    required String ticketId,
  }) async {
    try {
      final response = await _http.post(
        ApiEndpoints.staffTicketAssign(ticketId),
        queryParameters: {'facilityId': facilityId},
      );

      return StaffTicketMapper.fromJson(
        _unwrap(response.data),
      );
    } on ApiException catch (error) {
      throw _error(error, 'tiếp nhận yêu cầu này');
    }
  }

  Future<StaffTicketModel> assignToStaff({
    required String facilityId,
    required String ticketId,
    required String staffId,
  }) async {
    try {
      final response = await _http.post(
        ApiEndpoints.staffTicketAssignTo(ticketId, staffId),
        queryParameters: {'facilityId': facilityId},
      );

      return StaffTicketMapper.fromJson(
        _unwrap(response.data),
      );
    } on ApiException catch (error) {
      throw _error(error, 'giao yêu cầu này');
    }
  }

  Future<StaffTicketModel> updateStatus({
    required String facilityId,
    required String ticketId,
    required String status,
    String? resolutionNote,
  }) async {
    try {
      final response = await _http.patch(
        ApiEndpoints.staffTicketStatus(ticketId),
        queryParameters: {'facilityId': facilityId},
        data: StaffTicketMapper.statusRequestToJson(
          status: status,
          resolutionNote: resolutionNote,
        ),
      );

      return StaffTicketMapper.fromJson(
        _unwrap(response.data),
      );
    } on ApiException catch (error) {
      throw _error(error, 'cập nhật trạng thái yêu cầu');
    }
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return <String, dynamic>{};
  }

  Exception _error(ApiException error, String action) {
    final data = error.response?.data;
    final message = data is Map ? data['message']?.toString() : error.message;

    return Exception(
      'Không thể $action: ${message ?? 'Lỗi không xác định'}',
    );
  }
}
