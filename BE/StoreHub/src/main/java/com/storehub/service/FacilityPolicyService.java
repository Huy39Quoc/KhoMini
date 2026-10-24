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
            LocalDate currentEndDate
    );

    /** Ngày bắt đầu được phép gia hạn (ngày hết hạn trừ số ngày cửa sổ gia hạn); null nếu không giới hạn. */
    LocalDate getRenewalOpensDate(UUID facilityId, LocalDate currentEndDate);

    boolean isReturnNoticeSatisfied(
            UUID facilityId,
            LocalDateTime scheduledReturnTime
    );

    OverdueConfigResponse getOverdueConfig(UUID facilityId);

    // Kiem tra so thang thue >= minimumRentalMonths cua chinh sach co so
    // (mac dinh true neu co so chua thiet lap chinh sach nay).
    boolean isMinRentalMonthsSatisfied(UUID facilityId, int rentalMonths);

    // Kiem tra ngay bat dau thue (startDate) co nam trong khoang thoi gian dat truoc cho phep khong
    boolean isAdvanceReservationAllowed(UUID facilityId, LocalDate startDate);

    // Lay so ngay toi da cho phep dat truoc cua co so
    int getMaxAdvanceReservationDays(UUID facilityId);

    FacilityPolicyResponse getByFacilityId(UUID facilityId);

    FacilityPolicyResponse getForBooking(UUID facilityId);

    FacilityPolicyResponse create(FacilityPolicyCreateRequest request);

    FacilityPolicyResponse update(
            UUID id,
            FacilityPolicyUpdateRequest request
    );

    PageResponse<FacilityPolicyResponse> getAll(
            String search,
            int page,
            int size,
            String sortBy,
            String sortDir
    );
}
