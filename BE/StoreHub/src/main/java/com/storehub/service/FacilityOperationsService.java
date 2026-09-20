package com.storehub.service;

import com.storehub.dto.request.HandoverRequest;
import com.storehub.dto.request.UpdateUnitStatusRequest;
import com.storehub.dto.response.DailyScheduleResponse;
import com.storehub.dto.response.HandoverResponse;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface FacilityOperationsService {

    List<DailyScheduleResponse> getDailySchedule(
            UUID facilityId,
            LocalDate date
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
            UpdateUnitStatusRequest request
    );
}