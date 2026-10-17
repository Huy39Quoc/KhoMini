import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/paged_result.dart';

class TicketApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<PagedResult<Map<String, dynamic>>> getMyTickets({int page = 0}) async {
    try {
      final response = await _dio.get(ApiEndpoints.tickets,
          queryParameters: {'page': page, 'size': 20, 'sort': 'createdAt,desc'});
      return PagedResult.fromApi(response.data,
          (item) => Map<String, dynamic>.from(item as Map));
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được yêu cầu hỗ trợ: $message');
    }
  }

  Future<List<String>> uploadTicketPhotos(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];
    try {
      final formData = FormData();
      for (final path in filePaths) {
        final fileName = path.split(RegExp(r'[/\\]')).last;
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(path, filename: fileName),
        ));
      }
      final response = await _dio.post(
        ApiEndpoints.customerTicketsUploadPhotos,
        data: formData,
      );
      if (response.data is Map && response.data['data'] is List) {
        return (response.data['data'] as List).map((e) => e.toString()).toList();
      }
      return [];
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể tải ảnh lên: $message');
    }
  }

  Future<void> createTicket(
    String category,
    String title,
    String description,
    String bookingId, {
    List<String>? photos,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.tickets,
        data: {
          'category': category,
          'title': title,
          'description': description,
          'bookingId': bookingId,
          if (photos != null && photos.isNotEmpty) 'photos': photos,
        },
      );
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không thể gửi yêu cầu hỗ trợ: $message');
    }
  }

  Future<Map<String, dynamic>> getTicketDetail(String ticketId) async {
    try {
      final response = await _dio.get(ApiEndpoints.ticketDetail(ticketId));
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data']);
      }
      return data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Không tải được chi tiết yêu cầu: $message');
    }
  }
}
