package com.storehub.controller;

import com.storehub.common.ApiResponse;
import com.storehub.dto.request.FacilityUnitRequest;
import com.storehub.dto.response.*;
import com.storehub.service.FacilityManagementService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/facility/management")
@SecurityRequirement(name = "Bearer Authentication")
@RequiredArgsConstructor
public class FacilityManagementController {

    private final FacilityManagementService service;
    private final com.storehub.service.HandoverIssueService handoverIssues;

    @PostMapping("/{facilityId}/bookings/{bookingId}/handover-issue")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('BOOKING_UPDATE')")
    public ApiResponse<Void> resolveHandoverIssue(@PathVariable UUID facilityId, @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody com.storehub.dto.request.HandoverIssueResolutionRequest request) {
        handoverIssues.resolve(facilityId, bookingId, principal.getUsername(), request);
        return ApiResponse.success("Đã ghi nhận phương án xử lý sự cố bàn giao", null);
    }

    @GetMapping("/my-facility")
    @PreAuthorize("hasAnyRole('STAFF', 'FACILITY_MANAGER') and hasAuthority('FACILITY_VIEW')")
    public ApiResponse<AssignedFacilityResponse> myFacility(
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.myFacility(principal.getUsername())
        );
    }

    @GetMapping("/{facilityId}/units")
    @PreAuthorize("hasAnyRole('STAFF', 'FACILITY_MANAGER') and hasAuthority('STORAGE_UNIT_VIEW')")
    public ApiResponse<List<FacilityUnitResponse>> units(
            @PathVariable UUID facilityId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.units(
                        facilityId,
                        principal.getUsername()
                )
        );
    }

    @PostMapping("/{facilityId}/units")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('STORAGE_UNIT_CREATE')")
    public ApiResponse<FacilityUnitResponse> createUnit(
            @PathVariable UUID facilityId,
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody FacilityUnitRequest request
    ) {
        return ApiResponse.success(
                service.createUnit(
                        facilityId,
                        principal.getUsername(),
                        request
                )
        );
    }

    @PutMapping("/{facilityId}/units/{unitId}")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('STORAGE_UNIT_UPDATE')")
    public ApiResponse<FacilityUnitResponse> updateUnit(
            @PathVariable UUID facilityId,
            @PathVariable UUID unitId,
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody FacilityUnitRequest request
    ) {
        return ApiResponse.success(
                service.updateUnit(
                        facilityId,
                        unitId,
                        principal.getUsername(),
                        request
                )
        );
    }

    @PutMapping("/{facilityId}/bookings/{bookingId}/unit/{unitId}")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('BOOKING_UPDATE')")
    public ApiResponse<FacilityUnitResponse> assignUnit(
            @PathVariable UUID facilityId,
            @PathVariable UUID bookingId,
            @PathVariable UUID unitId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.assignUnit(
                        facilityId,
                        bookingId,
                        unitId,
                        principal.getUsername()
                )
        );
    }

    @GetMapping("/{facilityId}/report")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('REPORT_VIEW')")
    public ApiResponse<FacilityReportResponse> report(
            @PathVariable UUID facilityId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.report(
                        facilityId,
                        principal.getUsername()
                )
        );
    }

    @GetMapping("/{facilityId}/staff")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('STAFF_ASSIGNMENT_VIEW')")
    public ApiResponse<List<FacilityStaffResponse>> staff(
            @PathVariable UUID facilityId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.staff(
                        facilityId,
                        principal.getUsername()
                )
        );
    }

    @GetMapping("/{facilityId}/staff/assignable")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('STAFF_ASSIGNMENT_VIEW')")
    public ApiResponse<List<AssignableStaffResponse>> assignableStaff(
            @PathVariable UUID facilityId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.assignableStaff(facilityId, principal.getUsername())
        );
    }

    @PutMapping("/{facilityId}/staff/{userId}")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('STAFF_ASSIGNMENT_CREATE')")
    public ApiResponse<FacilityStaffResponse> assignStaff(
            @PathVariable UUID facilityId,
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.assignPerson(
                        facilityId,
                        userId,
                        "STAFF",
                        principal.getUsername()
                )
        );
    }

    @PutMapping("/{facilityId}/managers/{userId}")
    @PreAuthorize("hasRole('ADMIN') and hasAuthority('STAFF_ASSIGNMENT_CREATE')")
    public ApiResponse<FacilityStaffResponse> assignManager(
            @PathVariable UUID facilityId,
            @PathVariable UUID userId
    ) {
        return ApiResponse.success(
                service.assignPerson(
                        facilityId,
                        userId,
                        "FACILITY_MANAGER",
                        null
                )
        );
    }

    @DeleteMapping("/{facilityId}/staff/{userId}")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('STAFF_ASSIGNMENT_DELETE')")
    public ApiResponse<Void> unassignStaff(
            @PathVariable UUID facilityId,
            @PathVariable UUID userId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        service.unassignStaff(
                facilityId,
                userId,
                principal.getUsername()
        );

        return ApiResponse.success(
                "Staff unassigned from facility successfully",
                null
        );
    }

    @GetMapping("/{facilityId}/bookings")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('BOOKING_VIEW')")
    public ApiResponse<List<FacilityContractResponse>> contracts(
            @PathVariable UUID facilityId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.contracts(
                        facilityId,
                        principal.getUsername()
                )
        );
    }

    @PutMapping("/{facilityId}/bookings/{bookingId}/sealing/approve")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('BOOKING_UPDATE')")
    public ApiResponse<FacilityContractResponse> approveSealing(
            @PathVariable UUID facilityId,
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.approveSealing(
                        facilityId,
                        bookingId,
                        principal.getUsername()
                )
        );
    }

    @GetMapping("/{facilityId}/bookings/confirmed")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('BOOKING_VIEW')")
    public ApiResponse<List<FacilityBookingResponse>> confirmedBookings(
            @PathVariable UUID facilityId,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return ApiResponse.success(
                service.confirmedBookings(
                        facilityId,
                        principal.getUsername()
                )
        );
    }
}
