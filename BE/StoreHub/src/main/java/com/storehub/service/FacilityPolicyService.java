package com.storehub.service;

import com.storehub.common.PageResponse;
import com.storehub.dto.request.FacilityPolicyCreateRequest;
import com.storehub.dto.request.FacilityPolicyUpdateRequest;
import com.storehub.dto.response.FacilityPolicyResponse;
import com.storehub.dto.response.OverdueConfigResponse;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

public interface FacilityPolicyService {

    FacilityPolicyResponse getById(UUID id);

    boolean isWithinRenewalWindow(
            UUID facilityId,
            LocalDate endDate
    );

    boolean isMinRentalMonthsSatisfied(
            UUID facilityId,
            int months
    );

    default boolean isMinRentalMonthsSatisfied(
            UUID facilityId,
            Integer months
    ) {
        return months != null && isMinRentalMonthsSatisfied(facilityId, months.intValue());
    }

    boolean isReturnNoticeSatisfied(
            UUID facilityId,
            LocalDateTime scheduledReturn
    );

    default boolean isReturnNoticeSatisfied(
            UUID facilityId,
            LocalDate scheduledReturn
    ) {
        return scheduledReturn != null && isReturnNoticeSatisfied(facilityId, scheduledReturn.atStartOfDay());
    }

    OverdueConfigResponse getOverdueConfig(UUID facilityId);

    Double resolveDepositPercentage(UUID facilityId);

    FacilityPolicyResponse getByFacilityId(UUID facilityId);

    FacilityPolicyResponse create(FacilityPolicyCreateRequest request);

    FacilityPolicyResponse update(
            UUID id,
            FacilityPolicyUpdateRequest request
    );

    void delete(UUID id);

    PageResponse<FacilityPolicyResponse> getAll(
            String search,
            int page,
            int size,
            String sortBy,
            String sortDir
    );
}