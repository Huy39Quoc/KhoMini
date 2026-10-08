import 'package:dio/dio.dart';
import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../models/payment_model.dart';

class PaymentApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<List<PaymentModel>> getMyPayments() async {
    try {
      final response = await _dio.get(ApiEndpoints.paymentMyHistory);
      final rawData = _extractList(response.data);
      return rawData.map((json) => PaymentModel.fromJson(json)).toList();
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load payment history: $message');
    }
  }

  Future<List<PaymentModel>> getFacilityPayments(String facilityId) async {
    try {
      final response = await _dio.get(ApiEndpoints.paymentFacilityHistory(facilityId));
      final rawData = _extractList(response.data);
      return rawData.map((json) => PaymentModel.fromJson(json)).toList();
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load facility payments: $message');
    }
  }

  Future<List<PaymentModel>> getAllPayments() async {
    try {
      final response = await _dio.get(ApiEndpoints.paymentAllHistory);
      final rawData = _extractList(response.data);
      return rawData.map((json) => PaymentModel.fromJson(json)).toList();
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load system payment history: $message');
    }
  }

  Future<PaymentModel> getPaymentDetail(String paymentId) async {
    try {
      final response = await _dio.get(ApiEndpoints.paymentDetail(paymentId));
      final data = _extractObject(response.data);
      return PaymentModel.fromJson(data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message;
      throw Exception('Failed to load payment detail: $message');
    }
  }

  List<dynamic> _extractList(dynamic responseData) {
    if (responseData is List) {
      return responseData;
    } else if (responseData is Map) {
      if (responseData['data'] is List) {
        return responseData['data'];
      } else if (responseData['result'] is List) {
        return responseData['result'];
      }
    }
    return [];
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
}
