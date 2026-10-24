package com.storehub.service.impl;

import com.storehub.common.PageResponse;
import com.storehub.dto.request.FacilityPolicyCreateRequest;
import com.storehub.dto.request.FacilityPolicyUpdateRequest;
import com.storehub.dto.response.FacilityPolicyResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.FacilityPolicy;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.mapper.FacilityPolicyMapper;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.enums.ActivityAction;
import com.storehub.service.ActivityLogService;
import com.storehub.service.FacilityPolicyService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.storehub.dto.response.OverdueConfigResponse;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class FacilityPolicyServiceImpl implements FacilityPolicyService {

    private final FacilityPolicyRepository facilityPolicyRepository;
    private final FacilityRepository facilityRepository;
    private final FacilityPolicyMapper facilityPolicyMapper;
    private final ActivityLogService activityLogService;

    @Override
    public FacilityPolicyResponse getById(UUID id) {
        FacilityPolicy policy = facilityPolicyRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_POLICY_NOT_FOUND));
        return facilityPolicyMapper.toResponse(policy);
    }

    @Override
    @Transactional(readOnly = true, noRollbackFor = AppException.class)
    public FacilityPolicyResponse getByFacilityId(UUID facilityId) {
        FacilityPolicy policy = facilityPolicyRepository.findByFacility_Id(facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_POLICY_NOT_FOUND));
        return facilityPolicyMapper.toResponse(policy);
    }

    @Override
    @Transactional(propagation = org.springframework.transaction.annotation.Propagation.MANDATORY)
    public FacilityPolicyResponse getForBooking(UUID facilityId) {
        return facilityPolicyMapper.toResponse(facilityPolicyRepository.lockByFacilityId(facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.TERMS_NOT_AVAILABLE)));
    }

    @Override
    public FacilityPolicyResponse create(FacilityPolicyCreateRequest request) {
        if (request.getCancellationFullRefundHours() != null
                && request.getCancellationPartialRefundHours() != null
                && request.getCancellationFullRefundHours() < request.getCancellationPartialRefundHours()) {
            throw new AppException(ErrorCode.FACILITY_POLICY_INVALID_CANCELLATION);
        }

        Facility facility = facilityRepository.findById(request.getFacilityId())
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));

        if (facilityPolicyRepository.existsByFacility_Id(facility.getId())) {
            throw new AppException(ErrorCode.FACILITY_POLICY_ALREADY_EXISTS);
        }

        FacilityPolicy policy = FacilityPolicy.builder()
                .cancellationPolicyEffectiveAt(LocalDateTime.now())
                .facility(facility)
                .depositPercentage(request.getDepositPercentage())
                .renewalWindowDays(request.getRenewalWindowDays())
                .cancellationFullRefundHours(request.getCancellationFullRefundHours())
                .cancellationPartialRefundHours(request.getCancellationPartialRefundHours())
                .cancellationPartialRefundPercent(request.getCancellationPartialRefundPercent())
                .returnNoticeDays(request.getReturnNoticeDays())
                .depositRefundSlaDays(request.getDepositRefundSlaDays())
                .dailyLateFee(request.getDailyLateFee())
                .overdueGraceDays(request.getOverdueGraceDays())
                .overdueAccessDisableDays(request.getOverdueAccessDisableDays())
                .overdueSealingDays(request.getOverdueSealingDays())
                .minimumRentalMonths(request.getMinimumRentalMonths())
                .maxAdvanceReservationDays(request.getMaxAdvanceReservationDays() != null
                        ? request.getMaxAdvanceReservationDays() : 14)
                .managementFeePerMonth(request.getManagementFeePerMonth() != null
                        ? request.getManagementFeePerMonth() : java.math.BigDecimal.valueOf(50000))
                .longTermDiscountMinMonths(request.getLongTermDiscountMinMonths() != null
                        ? request.getLongTermDiscountMinMonths() : 0)
                .longTermDiscountPercent(request.getLongTermDiscountPercent() != null
                        ? request.getLongTermDiscountPercent() : 0.0)
                .prohibitedItems(request.getProhibitedItems())
                .termsAndConditions(request.getTermsAndConditions())
                .termsVersion(request.getTermsVersion() != null && !request.getTermsVersion().isBlank()
                        ? request.getTermsVersion() : "v2026.1")
                .build();

        FacilityPolicy saved = facilityPolicyRepository.save(policy);

        activityLogService.record(ActivityAction.FACILITY_POLICY_CREATE, "FACILITY_POLICY", saved.getId(),
                "Created policy for facility " + facility.getName(), null, facility.getId());

        return facilityPolicyMapper.toResponse(saved);
    }

    @Override
    public FacilityPolicyResponse update(UUID id, FacilityPolicyUpdateRequest request) {
        FacilityPolicy policy = facilityPolicyRepository.lockById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_POLICY_NOT_FOUND));

        boolean textChanged = (request.getTermsAndConditions() != null
                && !request.getTermsAndConditions().equals(policy.getTermsAndConditions()))
                || (request.getProhibitedItems() != null
                && !request.getProhibitedItems().equals(policy.getProhibitedItems()));
        if (textChanged && (request.getTermsVersion() == null || request.getTermsVersion().isBlank()
                || request.getTermsVersion().equals(policy.getTermsVersion()))) {
            throw new AppException(ErrorCode.TERMS_VERSION_REQUIRED);
        }

        int fullHours = request.getCancellationFullRefundHours() != null
                ? request.getCancellationFullRefundHours()
                : policy.getCancellationFullRefundHours();
        int partialHours = request.getCancellationPartialRefundHours() != null
                ? request.getCancellationPartialRefundHours()
                : policy.getCancellationPartialRefundHours();

        if (fullHours < partialHours) {
            throw new AppException(ErrorCode.FACILITY_POLICY_INVALID_CANCELLATION);
        }

        boolean cancellationChanged = fullHours != policy.getCancellationFullRefundHours()
                || partialHours != policy.getCancellationPartialRefundHours()
                || (request.getCancellationPartialRefundPercent() != null
                    && !request.getCancellationPartialRefundPercent().equals(policy.getCancellationPartialRefundPercent()));
        facilityPolicyMapper.updateEntityFromRequest(request, policy);
        if (cancellationChanged) {
            policy.setCancellationPolicyEffectiveAt(LocalDateTime.now());
        }
        FacilityPolicy updated = facilityPolicyRepository.save(policy);

        activityLogService.record(ActivityAction.FACILITY_POLICY_UPDATE, "FACILITY_POLICY", updated.getId(),
                "Updated policy for facility " + (policy.getFacility() != null ? policy.getFacility().getName() : updated.getId()), null, updated.getId());

        return facilityPolicyMapper.toResponse(updated);
    }

    @Override
    public boolean isWithinRenewalWindow(UUID facilityId, LocalDate currentEndDate) {
        return facilityPolicyRepository.findByFacility_Id(facilityId)
                .map(policy -> {
                    if (policy.getRenewalWindowDays() == null) {
                        return true;
                    }
                    LocalDate windowOpensAt = currentEndDate.minusDays(policy.getRenewalWindowDays());
                    LocalDate today = LocalDate.now();
                    return !today.isBefore(windowOpensAt);
                })
                .orElse(true);
    }

    @Override
    public LocalDate getRenewalOpensDate(UUID facilityId, LocalDate currentEndDate) {
        if (currentEndDate == null) {
            return null;
        }
        return facilityPolicyRepository.findByFacility_Id(facilityId)
                .map(policy -> policy.getRenewalWindowDays() == null
                        ? null
                        : currentEndDate.minusDays(policy.getRenewalWindowDays()))
                .orElse(null);
    }

    @Override
    public boolean isReturnNoticeSatisfied(UUID facilityId, LocalDateTime scheduledReturnTime) {
        if (scheduledReturnTime == null || !scheduledReturnTime.isAfter(LocalDateTime.now())) {
            return false;
        }
        return facilityPolicyRepository.findByFacility_Id(facilityId)
                .map(policy -> {
                    if (policy.getReturnNoticeDays() == null || policy.getReturnNoticeDays() <= 0) {
                        return true;
                    }
                    long daysNotice = ChronoUnit.DAYS.between(LocalDate.now(), scheduledReturnTime.toLocalDate());
                    return daysNotice >= policy.getReturnNoticeDays();
                })
                .orElse(true);
    }

    @Override
    public boolean isMinRentalMonthsSatisfied(UUID facilityId, int rentalMonths) {
        return facilityPolicyRepository.findByFacility_Id(facilityId)
                .map(policy -> policy.getMinimumRentalMonths() == null
                        || rentalMonths >= policy.getMinimumRentalMonths())
                .orElse(true);
    }

    @Override
    public boolean isAdvanceReservationAllowed(UUID facilityId, LocalDate startDate) {
        if (startDate == null) {
            return false;
        }
        LocalDate today = LocalDate.now();
        if (startDate.isBefore(today)) {
            return false;
        }
        int maxDays = getMaxAdvanceReservationDays(facilityId);
        return !startDate.isAfter(today.plusDays(maxDays));
    }

    @Override
    public int getMaxAdvanceReservationDays(UUID facilityId) {
        return facilityPolicyRepository.findByFacility_Id(facilityId)
                .map(policy -> policy.getMaxAdvanceReservationDays() != null
                        ? policy.getMaxAdvanceReservationDays() : 14)
                .orElse(14);
    }

    @Override
    public PageResponse<FacilityPolicyResponse> getAll(String search, int page, int size, String sortBy, String sortDir) {
        String resolvedSortBy = "facilityName".equalsIgnoreCase(sortBy) ? "facility.name" : sortBy;
        Sort sort = sortDir.equalsIgnoreCase("desc")
                ? Sort.by(resolvedSortBy).descending()
                : Sort.by(resolvedSortBy).ascending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<FacilityPolicyResponse> result = facilityPolicyRepository.findAllWithFilters(search, pageable)
                .map(facilityPolicyMapper::toResponse);
        return PageResponse.from(result);
    }

    @Override
    @Transactional(readOnly = true)
    public OverdueConfigResponse getOverdueConfig(UUID facilityId) {
        FacilityPolicy policy = facilityPolicyRepository
                .findByFacility_Id(facilityId)
                .orElseThrow(() ->
                        new AppException(ErrorCode.FACILITY_POLICY_NOT_FOUND)
                );

        return new OverdueConfigResponse(
                policy.getOverdueGraceDays(),
                policy.getDailyLateFee(),
                policy.getOverdueAccessDisableDays(),
                policy.getOverdueSealingDays()
        );
    }
}
