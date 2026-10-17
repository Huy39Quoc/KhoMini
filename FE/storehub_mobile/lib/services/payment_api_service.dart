import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../mappers/payment_mapper.dart';
import '../models/payment_model.dart';

class PaymentPage {
  final List<PaymentModel> items;
  final bool hasMore;

  const PaymentPage(this.items, this.hasMore);
}

class PaymentApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<PaymentPage> getMyPayments({int page = 0}) async {
    try {
      final response = await _dio
          .get(ApiEndpoints.paymentMyHistory, queryParameters: {'page': page});
      return _extractPage(response.data);
    } on DioException catch (e) {
      final message = _errorMessage(e);
      throw Exception('Không tải được lịch sử giao dịch: $message');
    }
  }

  Future<PaymentPage> getFacilityPayments(String facilityId,
      {int page = 0}) async {
    try {
      final response = await _dio.get(
          ApiEndpoints.paymentFacilityHistory(facilityId),
          queryParameters: {'page': page});
      return _extractPage(response.data);
    } on DioException catch (e) {
      final message = _errorMessage(e);
      throw Exception('Không tải được giao dịch của cơ sở: $message');
    }
  }

  Future<PaymentPage> getAllPayments({int page = 0}) async {
    try {
      final response = await _dio
          .get(ApiEndpoints.paymentAllHistory, queryParameters: {'page': page});
      return _extractPage(response.data);
    } on DioException catch (e) {
      final message = _errorMessage(e);
      throw Exception('Không tải được lịch sử giao dịch hệ thống: $message');
    }
  }

  Future<PaymentModel> getPaymentDetail(String paymentId) async {
    try {
      final response = await _dio.get(ApiEndpoints.paymentDetail(paymentId));
      final data = _extractObject(response.data);
      return PaymentMapper.fromJson(data);
    } on DioException catch (e) {
      final message = _errorMessage(e);
      throw Exception('Không tải được chi tiết giao dịch: $message');
    }
  }

  PaymentPage _extractPage(dynamic responseData) {
    final envelope = responseData is Map ? responseData : const {};
    final data = envelope['data'] ?? envelope['result'];
    if (data is! Map || data['content'] is! List) {
      throw const FormatException('Dữ liệu lịch sử thanh toán không hợp lệ');
    }
    final items = (data['content'] as List)
        .map((json) => PaymentMapper.fromJson(PaymentMapper.asJsonMap(json)))
        .toList();
    return PaymentPage(items, data['last'] == false);
  }

  Map<String, dynamic> _extractObject(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData['data'] is Map<String, dynamic>) {
        return responseData['data'];
      } else if (responseData['result'] is Map<String, dynamic>) {
        return responseData['result'];
      }
      return responseData;
    }
    return {};
  }

  String _errorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return error.message ?? 'Lỗi không xác định';
  }
}
