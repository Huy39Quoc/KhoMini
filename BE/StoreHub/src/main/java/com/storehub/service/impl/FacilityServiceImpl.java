package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.FacilityCreateRequest;
import com.storehub.dto.request.FacilityUpdateRequest;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.User;
import com.storehub.enums.ActivityAction;
import com.storehub.enums.FacilityStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.mapper.FacilityMapper;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.FacilityService;
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
public class FacilityServiceImpl implements FacilityService {

    private final FacilityRepository facilityRepository;
    private final UserRepository userRepository;
    private final FacilityMapper facilityMapper;
    private final ActivityLogService activityLogService;

    @Override
    public FacilityResponse getById(UUID id) {
        Facility facility = facilityRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));

        return facilityMapper.toResponse(facility);
    }

    @Override
    public FacilityResponse create(FacilityCreateRequest request) {
        if (facilityRepository.existsByCode(request.getCode())) {
            throw new AppException(ErrorCode.FACILITY_CODE_EXISTED);
        }

        Facility facility = facilityMapper.toEntity(request);

        if (request.getManagerId() != null) {
            User manager = userRepository.findById(request.getManagerId())
                    .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

            if (!Boolean.TRUE.equals(manager.getIsActive())
                    || manager.getRole() == null
                    || !"FACILITY_MANAGER".equals(manager.getRole().getName())
                    || manager.getFacility() != null) {
                throw new AppException(ErrorCode.INVALID_MANAGER_TO_ASSIGN);
            }

            facility.setManager(manager);
        }

        Facility saved = facilityRepository.save(facility);

        if (saved.getManager() != null) {
            saved.getManager().setFacility(saved);
        }

        activityLogService.record(
                ActivityAction.FACILITY_CREATE,
                "FACILITY",
                saved.getId(),
                "Created facility: "
                        + saved.getName()
                        + " ("
                        + saved.getCode()
                        + ")",
                null,
                saved.getCode()
        );

        return facilityMapper.toResponse(saved);
    }

    @Override
    public FacilityResponse update(UUID id, FacilityUpdateRequest request) {
        Facility facility = facilityRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));

        if (request.getCode() != null
                && facilityRepository.existsByCodeAndIdNot(
                request.getCode(),
                facility.getId()
        )) {
            throw new AppException(ErrorCode.FACILITY_CODE_EXISTED);
        }

        facilityMapper.updateEntityFromRequest(request, facility);

        if (request.getManagerId() != null) {
            User manager = userRepository.findById(request.getManagerId())
                    .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

            if (!Boolean.TRUE.equals(manager.getIsActive())
                    || manager.getRole() == null
                    || !"FACILITY_MANAGER".equals(manager.getRole().getName())) {
                throw new AppException(ErrorCode.INVALID_MANAGER_TO_ASSIGN);
            }

            User previousManager = facility.getManager();

            if (previousManager != null
                    && !previousManager.getId().equals(manager.getId())
                    && previousManager.getFacility() != null
                    && facility.getId().equals(
                    previousManager.getFacility().getId()
            )) {
                previousManager.setFacility(null);
            }

            Facility previousFacility = manager.getFacility();

            if (previousFacility != null
                    && !facility.getId().equals(previousFacility.getId())
                    && previousFacility.getManager() != null
                    && manager.getId().equals(
                    previousFacility.getManager().getId()
            )) {
                previousFacility.setManager(null);
            }

            facility.setManager(manager);
            manager.setFacility(facility);
        }

        if (request.getStatus() != null) {
            try {
                facility.setStatus(
                        FacilityStatus.valueOf(
                                request.getStatus().toUpperCase()
                        )
                );
            } catch (IllegalArgumentException e) {
                throw new AppException(ErrorCode.INVALID_REQUEST);
            }
        }

        Facility updated = facilityRepository.save(facility);

        activityLogService.record(
                ActivityAction.FACILITY_UPDATE,
                "FACILITY",
                updated.getId(),
                "Updated facility: " + updated.getName(),
                null,
                updated.getStatus()
        );

        return facilityMapper.toResponse(updated);
    }

    @Override
    public void delete(UUID id) {
        Facility facility = facilityRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));

        facilityRepository.deleteById(facility.getId());

        activityLogService.record(
                ActivityAction.FACILITY_DEACTIVATE,
                "FACILITY",
                facility.getId(),
                "Deleted facility: " + facility.getName(),
                null,
                null
        );
    }

    @Override
    public PageResponse<FacilityResponse> getAll(
            String search,
            FacilityStatus status,
            int page,
            int size,
            String sortBy,
            String sortDir
    ) {
        Sort sort = sortDir.equalsIgnoreCase("desc")
                ? Sort.by(sortBy).descending()
                : Sort.by(sortBy).ascending();

        Pageable pageable = PageRequest.of(page, size, sort);

        Page<FacilityResponse> result = facilityRepository
                .findAllWithFilters(search, status, pageable)
                .map(facilityMapper::toResponse);

        return PageResponse.from(result);
    }
}