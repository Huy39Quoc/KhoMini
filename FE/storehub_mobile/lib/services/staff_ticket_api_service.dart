import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../mappers/staff_ticket_mapper.dart';
import '../models/staff_ticket_model.dart';
import '../models/paged_result.dart';

class StaffTicketApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<PagedResult<StaffTicketModel>> getFacilityTickets(
    String facilityId, {int page = 0}
  ) async {
    try {
      final response = await _dio.get(
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
    } on DioException catch (error) {
      throw _error(error, 'load facility tickets');
    }
  }

  Future<StaffTicketModel> assignToMe({
    required String facilityId,
    required String ticketId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.staffTicketAssign(ticketId),
        queryParameters: {'facilityId': facilityId},
      );

      return StaffTicketMapper.fromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _error(error, 'accept this ticket');
    }
  }

  Future<StaffTicketModel> assignToStaff({
    required String facilityId,
    required String ticketId,
    required String staffId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.staffTicketAssignTo(ticketId, staffId),
        queryParameters: {'facilityId': facilityId},
      );

      return StaffTicketMapper.fromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _error(error, 'assign this ticket');
    }
  }

  Future<StaffTicketModel> updateStatus({
    required String facilityId,
    required String ticketId,
    required String status,
    String? resolutionNote,
  }) async {
    try {
      final response = await _dio.patch(
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
    } on DioException catch (error) {
      throw _error(error, 'update ticket status');
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

  Exception _error(DioException error, String action) {
    final data = error.response?.data;
    final message = data is Map ? data['message']?.toString() : error.message;

    return Exception(
      'Failed to $action: ${message ?? 'Unknown error'}',
    );
  }
}
