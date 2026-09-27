package com.storehub.service;

import com.storehub.dto.request.FacilityUnitRequest;
import com.storehub.dto.response.AssignedFacilityResponse;
import com.storehub.dto.response.FacilityReportResponse;
import com.storehub.dto.response.FacilityStaffResponse;
import com.storehub.dto.response.FacilityUnitResponse;

import java.util.List;
import java.util.UUID;

public interface FacilityManagementService {

    AssignedFacilityResponse myFacility(String email);

    List<FacilityUnitResponse> units(
            UUID facilityId,
            String managerEmail
    );

    FacilityUnitResponse createUnit(
            UUID facilityId,
            String managerEmail,
            FacilityUnitRequest request
    );

    FacilityUnitResponse updateUnit(
            UUID facilityId,
            UUID unitId,
            String managerEmail,
            FacilityUnitRequest request
    );

    FacilityUnitResponse assignUnit(
            UUID facilityId,
            UUID bookingId,
            UUID unitId,
            String managerEmail
    );

    FacilityReportResponse report(
            UUID facilityId,
            String managerEmail
    );

    FacilityStaffResponse assignPerson(
            UUID facilityId,
            UUID userId,
            String role,
            String managerEmail
    );

    List<FacilityStaffResponse> staff(
            UUID facilityId,
            String managerEmail
    );

    void unassignStaff(
            UUID facilityId,
            UUID userId,
            String managerEmail
    );
}