import 'package:dio/dio.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/http_client.dart';
import '../mappers/facility_operations_mapper.dart';
import '../models/facility_operations_models.dart';
import '../mappers/facility_management_mapper.dart';
import '../models/facility_management_models.dart';

class FacilityOpsApiService {
  final Dio _dio = HttpClient.instance.dio;

  Future<Map<String, dynamic>> verifyGatePass({
    required String facilityId,
    required String token,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.verifyGatePass,
          queryParameters: {'facilityId': facilityId}, data: {'token': token});
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _err(e, 'kiểm tra mã QR cổng');
    }
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return <String, dynamic>{};
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is Map && data['data'] is List) {
      return List<dynamic>.from(data['data']);
    }

    if (data is List) {
      return data;
    }

    return <dynamic>[];
  }

  Exception _err(DioException error, String action) {
    final responseData = error.response?.data;

    String? message;

    if (responseData is Map) {
      message = responseData['message']?.toString();
    }

    message ??= error.message;

    return Exception(
      'Không thể $action: ${message ?? 'Lỗi không xác định'}',
    );
  }

  // =========================================================
  // Facility Manager - Flow 5
  // Tạm thời giữ Map/dynamic, sẽ đổi sang mapper khi làm Flow 5
  // =========================================================

  // =========================================================
// Facility Manager - Flow 5
// =========================================================

  Future<List<FacilityUnitModel>> getFacilityUnits(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityUnits(facilityId),
      );

      return _unwrapList(response.data)
          .map(FacilityManagementMapper.asJsonMap)
          .map(FacilityManagementMapper.unitFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'tải danh sách ngăn kho');
    }
  }

  Future<FacilityUnitModel> createFacilityUnit(
    String facilityId, {
    required String unitCode,
    String? floorLevel,
    required String unitTypeId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.facilityUnits(facilityId),
        data: FacilityManagementMapper.unitRequestToJson(
          unitCode: unitCode,
          floorLevel: floorLevel,
          unitTypeId: unitTypeId,
        ),
      );

      return FacilityManagementMapper.unitFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'tạo ngăn kho');
    }
  }

  Future<FacilityUnitModel> updateFacilityUnit(
    String facilityId,
    String unitId, {
    required String unitCode,
    String? floorLevel,
    required String unitTypeId,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.facilityUnitDetail(
          facilityId,
          unitId,
        ),
        data: FacilityManagementMapper.unitRequestToJson(
          unitCode: unitCode,
          floorLevel: floorLevel,
          unitTypeId: unitTypeId,
        ),
      );

      return FacilityManagementMapper.unitFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'cập nhật ngăn kho');
    }
  }

  Future<FacilityUnitModel> assignUnitToBooking(
    String facilityId,
    String bookingId,
    String unitId,
  ) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.facilityAssignUnit(
          facilityId,
          bookingId,
          unitId,
        ),
      );

      return FacilityManagementMapper.unitFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'xác nhận ngăn kho cho đơn');
    }
  }

  Future<FacilityReportModel> getFacilityManagerReport(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityManagerReport(
          facilityId,
        ),
      );

      return FacilityManagementMapper.reportFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'tải báo cáo cơ sở');
    }
  }

  Future<List<FacilityStaffModel>> getFacilityStaff(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityStaffList(
          facilityId,
        ),
      );

      return _unwrapList(response.data)
          .map(FacilityManagementMapper.asJsonMap)
          .map(FacilityManagementMapper.staffFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'tải danh sách nhân viên');
    }
  }

  Future<List<AssignableUserModel>> getAssignableUsers(String facilityId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityAssignableStaff(facilityId),
      );

      return _unwrapList(response.data)
          .map(FacilityManagementMapper.asJsonMap)
          .map(
            FacilityManagementMapper.assignableUserFromJson,
          )
          .where(
            (user) =>
                user.id.isNotEmpty &&
                user.isActive &&
                user.roleName == 'STAFF',
          )
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'tải danh sách người có thể thêm');
    }
  }

  Future<FacilityStaffModel> assignStaffToFacility(
    String facilityId,
    String userId,
  ) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.facilityAssignStaff(
          facilityId,
          userId,
        ),
      );

      return FacilityManagementMapper.staffFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'thêm nhân viên vào cơ sở');
    }
  }

  // PUT /facility/management/{facilityId}/managers/{userId} (ADMIN only).
  Future<FacilityStaffModel> assignManagerToFacility(
    String facilityId,
    String userId,
  ) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.facilityAssignManager(
          facilityId,
          userId,
        ),
      );

      return FacilityManagementMapper.staffFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'thêm nhân viên');
    }
  }

  Future<void> unassignStaff(
    String facilityId,
    String userId,
  ) async {
    try {
      await _dio.delete(
        ApiEndpoints.facilityAssignStaff(
          facilityId,
          userId,
        ),
      );
    } on DioException catch (error) {
      throw _err(error, 'gỡ nhân viên');
    }
  }

  Future<List<FacilityBookingModel>> getConfirmedBookings(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityConfirmedBookings(facilityId),
      );

      return _unwrapList(response.data)
          .map(FacilityManagementMapper.asJsonMap)
          .map(FacilityManagementMapper.bookingFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'tải các đơn đã xác nhận');
    }
  }
  /// Hợp đồng đang CONFIRMED / ACTIVE của cơ sở (Facility Manager theo dõi).
  Future<List<FacilityContractModel>> getFacilityContracts(
    String facilityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.facilityContracts(facilityId),
      );

      return _unwrapList(response.data)
          .map(FacilityManagementMapper.asJsonMap)
          .map(FacilityManagementMapper.contractFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'tải hợp đồng của cơ sở');
    }
  }

  /// Facility Manager duyệt niêm phong cho hợp đồng quá hạn đang "chờ niêm phong".
  Future<void> approveSealing(String facilityId, String bookingId) async {
    try {
      await _dio.put(ApiEndpoints.approveSealing(facilityId, bookingId));
    } on DioException catch (error) {
      throw _err(error, 'duyệt niêm phong');
    }
  }

  /// Staff cấp lại PIN cho khách quên mã (sau khi xác minh khách tại quầy).
  /// Trả về PIN mới - server chỉ trả đúng một lần.
  Future<String> resetCustomerPin(String bookingId, String facilityId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.resetCustomerPin(bookingId),
        queryParameters: {'facilityId': facilityId},
      );
      final data = _unwrap(response.data);
      return data['generatedPin']?.toString() ?? '';
    } on DioException catch (error) {
      throw _err(error, 'đặt lại PIN cho khách');
    }
  }

  // =========================================================
  // Facility Staff - Flow 2
  // Các response được chuyển sang model bằng mapper
  // =========================================================

  Future<AssignedFacilityModel> getAssignedFacility() async {
    try {
      final response = await _dio.get(ApiEndpoints.myFacility);

      return FacilityOperationsMapper.assignedFacilityFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      // BE trả 403 (ErrorCode.FORBIDDEN) khi tài khoản chưa được gán cơ sở
      // (users.facility_id null). Đó không phải lỗi hệ thống: trả model rỗng để
      // màn hình hiện "No facility assigned" thay vì "Something went wrong".
      if (error.response?.statusCode == 403) {
        return const AssignedFacilityModel(id: '', name: '', address: '');
      }
      throw _err(error, 'tải cơ sở được phân công');
    }
  }

  Future<List<DailyScheduleModel>> getDailySchedule({
    required String facilityId,
    required DateTime date,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.dailySchedule,
        queryParameters: {
          'facilityId': facilityId,
          'date': _formatDate(date),
        },
      );

      return _unwrapList(response.data)
          .map(FacilityOperationsMapper.asJsonMap)
          .map(FacilityOperationsMapper.dailyScheduleFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'tải lịch làm việc trong ngày');
    }
  }

  Future<void> assignAppointment({
    required String facilityId,
    required DailyScheduleModel appointment,
    String? staffId,
  }) async {
    try {
      await _dio.put(
        ApiEndpoints.appointmentAssignment(appointment.bookingId),
        queryParameters: {'facilityId': facilityId},
        data: {'scheduleType': appointment.scheduleType, 'staffId': staffId},
      );
    } on DioException catch (error) {
      throw _err(error, 'phân công lịch hẹn');
    }
  }

  Future<Map<String, dynamic>> getFacilityRefunds(String facilityId,
      {int page = 0, int size = 20}) async {
    try {
      final response = await _dio.get(ApiEndpoints.facilityRefunds(facilityId),
          queryParameters: {'page': page, 'size': size});
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw _err(error, 'tải yêu cầu hoàn tiền');
    }
  }

  Future<void> provideRefundDetails(String facilityId, String refundId,
      String transactionDate, String transactionNo, num originalAmount) async {
    try {
      await _dio.put('${ApiEndpoints.facilityRefunds(facilityId)}/$refundId/gateway-details',
          data: {
            'transactionDate': transactionDate,
            'transactionNo': transactionNo.isEmpty ? null : transactionNo,
            'originalAmount': originalAmount,
          });
    } on DioException catch (error) {
      throw _err(error, 'nhập thông tin giao dịch gốc');
    }
  }

  Future<void> retryRejectedRefund(String facilityId, String refundId) async {
    try {
      await _dio.post('${ApiEndpoints.facilityRefunds(facilityId)}/$refundId/retry');
    } on DioException catch (error) {
      throw _err(error, 'gửi lại yêu cầu hoàn tiền bị từ chối');
    }
  }

  Future<void> reconcileRefund(String facilityId, String refundId) async {
    try {
      await _dio.post('${ApiEndpoints.facilityRefunds(facilityId)}/$refundId/reconcile');
    } on DioException catch (error) {
      throw _err(error, 'kiểm tra hoàn tiền với VNPay');
    }
  }

  Future<List<String>> uploadHandoverPhotos(List<String> filePaths) async {
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
        ApiEndpoints.facilityOpsUploadPhotos,
        data: formData,
      );
      if (response.data is Map && response.data['data'] is List) {
        return (response.data['data'] as List).map((e) => e.toString()).toList();
      }
      return [];
    } on DioException catch (error) {
      throw _err(error, 'tải ảnh bàn giao lên');
    }
  }

  Future<HandoverModel> checkIn({
    required String bookingId,
    required String facilityId,
    required String unitCondition,
    required String lockCondition,
    String? notes,
    List<String>? photos,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.checkIn(bookingId),
        queryParameters: {
          'facilityId': facilityId,
        },
        data: FacilityOperationsMapper.handoverRequestToJson(
          unitCondition: unitCondition,
          lockCondition: lockCondition,
          notes: notes,
          photos: photos,
        ),
      );

      return FacilityOperationsMapper.handoverFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'bàn giao kho cho khách này');
    }
  }

  Future<void> confirmBankTransfer(String facilityId, String refundId, {
    required String transferReference,
    String? notes,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.facilityRefunds(facilityId)}/$refundId/confirm-bank-transfer',
        data: {
          'transferReference': transferReference.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } on DioException catch (error) {
      throw _err(error, 'xác nhận đã chuyển khoản hoàn tiền');
    }
  }

  Future<HandoverModel> checkOut({
    required String bookingId,
    required String facilityId,
    required String unitCondition,
    required String lockCondition,
    String? notes,
    num? damageFee,
    String? damageReason,
    List<String>? photos,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.checkOut(bookingId),
        queryParameters: {
          'facilityId': facilityId,
        },
        data: FacilityOperationsMapper.handoverRequestToJson(
          unitCondition: unitCondition,
          lockCondition: lockCondition,
          notes: notes,
          damageFee: damageFee,
          damageReason: damageReason,
          photos: photos,
        ),
      );

      return FacilityOperationsMapper.handoverFromJson(
        _unwrap(response.data),
      );
    } on DioException catch (error) {
      throw _err(error, 'hoàn tất nghiệm thu');
    }
  }

  Future<List<HandoverRecordModel>> getHandoverHistory({
    required String bookingId,
    required String facilityId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.handoverRecords(bookingId),
        queryParameters: {
          'facilityId': facilityId,
        },
      );

      return _unwrapList(response.data)
          .map(FacilityOperationsMapper.asJsonMap)
          .map(FacilityOperationsMapper.handoverRecordFromJson)
          .toList();
    } on DioException catch (error) {
      throw _err(error, 'tải lịch sử bàn giao');
    }
  }

  Future<void> updateUnitStatus({
    required String unitId,
    required String facilityId,
    required String status,
  }) async {
    try {
      await _dio.patch(
        ApiEndpoints.updateUnitStatus(unitId),
        queryParameters: {
          'facilityId': facilityId,
        },
        data: {
          'status': status,
        },
      );
    } on DioException catch (error) {
      throw _err(error, 'cập nhật trạng thái ngăn kho');
    }
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${date.year.toString().padLeft(4, '0')}'
        '-${twoDigits(date.month)}'
        '-${twoDigits(date.day)}';
  }
}
