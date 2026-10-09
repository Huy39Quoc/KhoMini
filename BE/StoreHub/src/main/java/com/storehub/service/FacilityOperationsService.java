package com.storehub.service;

import com.storehub.dto.request.HandoverRequest;
import com.storehub.dto.request.UpdateUnitStatusRequest;
import com.storehub.dto.response.DailyScheduleResponse;
import com.storehub.dto.response.HandoverRecordResponse;
import com.storehub.dto.response.HandoverResponse;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface FacilityOperationsService {

    List<DailyScheduleResponse> getDailySchedule(
            UUID facilityId,
            LocalDate date,
            String staffEmail
    );

    DailyScheduleResponse assignAppointment(UUID bookingId, UUID facilityId,
                                            String managerEmail, String scheduleType, UUID staffId);

    List<HandoverRecordResponse> getHandoverHistory(
            UUID bookingId,
            UUID facilityId,
            String staffEmail
    );

    HandoverResponse checkIn(
            UUID bookingId,
            UUID facilityId,
            String staffEmail,
            HandoverRequest request
    );

    HandoverResponse checkOut(
            UUID bookingId,
            UUID facilityId,
            String staffEmail,
            HandoverRequest request
    );

    // Khách quên PIN và không tự đặt lại được: nhân viên (sau khi xác minh khách tại quầy) cấp PIN mới.
    // PIN mới chỉ trả về MỘT lần trong response; cửa được khóa lại.
    com.storehub.dto.response.SmartAccessResponse resetCustomerPin(
            UUID bookingId,
            UUID facilityId,
            String staffEmail
    );

    String updateUnitStatus(
            UUID unitId,
            UUID facilityId,
            String staffEmail,
            UpdateUnitStatusRequest request
    );
}
