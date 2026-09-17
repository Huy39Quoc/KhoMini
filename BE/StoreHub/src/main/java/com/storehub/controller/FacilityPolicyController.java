package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.FacilityPolicyCreateRequest;
import com.storehub.dto.request.FacilityPolicyUpdateRequest;
import com.storehub.dto.response.FacilityPolicyResponse;
import com.storehub.service.FacilityPolicyService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("api/v1/facility-policies")
@RequiredArgsConstructor
@Slf4j
public class FacilityPolicyController {
    private final FacilityPolicyService facilityPolicyService;

    @GetMapping("{id}")
    public ResponseEntity<ApiResponse<FacilityPolicyResponse>> getById(@PathVariable UUID id) {
        log.info("Get facility policy by id : {}", id);
        FacilityPolicyResponse response = facilityPolicyService.getById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/by-facility/{facilityId}")
    public ResponseEntity<ApiResponse<FacilityPolicyResponse>> getByFacilityId(@PathVariable UUID facilityId) {
        log.info("Get facility policy by facility id : {}", facilityId);
        FacilityPolicyResponse response = facilityPolicyService.getByFacilityId(facilityId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<FacilityPolicyResponse>> create
            (@Valid @RequestBody FacilityPolicyCreateRequest request) {
        log.info("Creating facility policy for facility : {}", request.getFacilityId());
        FacilityPolicyResponse response = facilityPolicyService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("Created facility policy successfully", response));
    }

    @PutMapping("{id}")
    public ResponseEntity<ApiResponse<FacilityPolicyResponse>> update
            (@PathVariable UUID id, @Valid @RequestBody FacilityPolicyUpdateRequest request) {
        log.info("Updating facility policy : {}", id);
        FacilityPolicyResponse response = facilityPolicyService.update(id, request);
        return ResponseEntity.ok(ApiResponse.success("Updated facility policy successfully.", response));
    }

    @DeleteMapping("{id}")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        log.info("Deleting facility policy with id : {}", id);
        facilityPolicyService.delete(id);
        return ResponseEntity.ok(ApiResponse.success("Deleted facility policy successfully.", null));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<FacilityPolicyResponse>>> getAll(
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "id") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir
    ) {
        log.info("Get all facility policies - page: {}, size: {}, search: {}", page, size, search);
        PageResponse<FacilityPolicyResponse> response = facilityPolicyService.getAll(search, page, size, sortBy, sortDir);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
