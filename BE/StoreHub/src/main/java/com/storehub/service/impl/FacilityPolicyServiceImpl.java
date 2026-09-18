package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
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
import com.storehub.service.FacilityPolicyService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class FacilityPolicyServiceImpl implements FacilityPolicyService {

    private final FacilityPolicyRepository facilityPolicyRepository;
    private final FacilityRepository facilityRepository;
    private final FacilityPolicyMapper facilityPolicyMapper;

    @Override
    public FacilityPolicyResponse getById(UUID id) {
        FacilityPolicy policy = facilityPolicyRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_POLICY_NOT_FOUND));
        return facilityPolicyMapper.toResponse(policy);
    }

    @Override
    public FacilityPolicyResponse getByFacilityId(UUID facilityId) {
        FacilityPolicy policy = facilityPolicyRepository.findByFacility_Id(facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_POLICY_NOT_FOUND));
        return facilityPolicyMapper.toResponse(policy);
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
                .build();

        FacilityPolicy saved = facilityPolicyRepository.save(policy);
        return facilityPolicyMapper.toResponse(saved);
    }

    @Override
    public FacilityPolicyResponse update(UUID id, FacilityPolicyUpdateRequest request) {
        FacilityPolicy policy = facilityPolicyRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_POLICY_NOT_FOUND));

        int fullHours = request.getCancellationFullRefundHours() != null
                ? request.getCancellationFullRefundHours()
                : policy.getCancellationFullRefundHours();
        int partialHours = request.getCancellationPartialRefundHours() != null
                ? request.getCancellationPartialRefundHours()
                : policy.getCancellationPartialRefundHours();

        if (fullHours < partialHours) {
            throw new AppException(ErrorCode.FACILITY_POLICY_INVALID_CANCELLATION);
        }

        facilityPolicyMapper.updateEntityFromRequest(request, policy);
        FacilityPolicy updated = facilityPolicyRepository.save(policy);
        return facilityPolicyMapper.toResponse(updated);
    }

    @Override
    public void delete(UUID id) {
        FacilityPolicy policy = facilityPolicyRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_POLICY_NOT_FOUND));
        facilityPolicyRepository.deleteById(policy.getId());
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
}
