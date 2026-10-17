package com.storehub.service;

import com.storehub.common.PageResponse;
import com.storehub.dto.request.FacilityCreateRequest;
import com.storehub.dto.request.FacilityUpdateRequest;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.enums.FacilityStatus;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

public interface FacilityService {
    FacilityResponse getById(UUID id);
    FacilityResponse create(FacilityCreateRequest request);
    FacilityResponse update(UUID id, FacilityUpdateRequest request);
    void delete(UUID id);
    PageResponse<FacilityResponse> getAll(String search, FacilityStatus status, int page, int size, String sortBy, String sortDir);
    String uploadImage(UUID id, MultipartFile file);
    String uploadImageOnly(MultipartFile file);
    List<String> uploadImagesOnly(MultipartFile[] files);
}