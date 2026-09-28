import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../mappers/staff_ticket_mapper.dart';
import '../models/staff_ticket_model.dart';

class StaffTicketApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<List<StaffTicketModel>> getFacilityTickets(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.staffTickets,
        queryParameters: {
          'facilityId': facilityId,
          'page': 0,
          'size': 100,
          'sort': 'createdAt,desc',
        },
      );

      return _unwrapPageContent(response.data)
          .map(StaffTicketMapper.asJsonMap)
          .map(StaffTicketMapper.fromJson)
          .toList();
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

  List<dynamic> _unwrapPageContent(dynamic data) {
    if (data is Map && data['data'] is Map && data['data']['content'] is List) {
      return List<dynamic>.from(data['data']['content']);
    }

    if (data is Map && data['content'] is List) {
      return List<dynamic>.from(data['content']);
    }

    return <dynamic>[];
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
