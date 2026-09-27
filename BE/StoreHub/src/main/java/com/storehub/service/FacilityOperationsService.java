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

    String updateUnitStatus(
            UUID unitId,
            UUID facilityId,
            String staffEmail,
            UpdateUnitStatusRequest request
    );
}