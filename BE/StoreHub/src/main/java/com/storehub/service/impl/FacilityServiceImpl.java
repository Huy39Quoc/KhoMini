package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.FacilityCreateRequest;
import com.storehub.dto.request.FacilityUpdateRequest;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.User;
import com.storehub.enums.FacilityStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.mapper.FacilityMapper;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.UserRepository;
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

            if(manager.getRole().getName().equalsIgnoreCase("manager")){
                facility.setManager(manager);
            }else{
                throw new AppException(ErrorCode.INVALID_MANAGER_TO_ASSIGN);
            }
        }

        Facility saved = facilityRepository.save(facility);
        return facilityMapper.toResponse(saved);
    }

    @Override
    public FacilityResponse update(UUID id, FacilityUpdateRequest request) {
        Facility facility = facilityRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));

        if (request.getCode() != null
                && facilityRepository.existsByCodeAndIdNot(request.getCode(), facility.getId())) {
            throw new AppException(ErrorCode.FACILITY_CODE_EXISTED);
        }

        facilityMapper.updateEntityFromRequest(request, facility);

        if (request.getManagerId() != null) {
            User manager = userRepository.findById(request.getManagerId())
                    .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
            facility.setManager(manager);
        }

        if (request.getStatus() != null) {
            try {
                facility.setStatus(FacilityStatus.valueOf(request.getStatus().toUpperCase()));
            } catch (IllegalArgumentException e) {
                throw new AppException(ErrorCode.INVALID_REQUEST);
            }
        }

        Facility updated = facilityRepository.save(facility);
        return facilityMapper.toResponse(updated);
    }

    @Override
    public void delete(UUID id) {
        Facility facility = facilityRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));
        facilityRepository.deleteById(facility.getId());
    }

    @Override
    public PageResponse<FacilityResponse> getAll(
            String search, FacilityStatus status, int page, int size, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc")
                ? Sort.by(sortBy).descending()
                : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<FacilityResponse> result = facilityRepository.findAllWithFilters(search, status, pageable)
                .map(facilityMapper::toResponse);
        return PageResponse.from(result);
    }
}