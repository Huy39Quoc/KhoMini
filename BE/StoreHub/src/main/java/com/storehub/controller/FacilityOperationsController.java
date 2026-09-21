package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.dto.request.HandoverRequest;
import com.storehub.dto.request.UpdateUnitStatusRequest;
import com.storehub.dto.response.DailyScheduleResponse;
import com.storehub.dto.response.HandoverResponse;
import com.storehub.service.FacilityOperationsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/facility/operations")
@RequiredArgsConstructor
@Tag(
        name = "Facility Operations",
        description = "APIs for storage check-in, check-out and handover"
)
@SecurityRequirement(name = "Bearer Authentication")
public class FacilityOperationsController {

    private final FacilityOperationsService facilityOperationsService;

    @GetMapping("/daily-schedule")
    @PreAuthorize("hasAnyRole('STAFF', 'FACILITY_MANAGER')")
    @Operation(
            summary = "Get daily check-in and check-out schedule"
    )
    public ResponseEntity<ApiResponse<List<DailyScheduleResponse>>> getDailySchedule(
            @RequestParam UUID facilityId,
            @RequestParam LocalDate date
    ) {

        List<DailyScheduleResponse> result =
                facilityOperationsService.getDailySchedule(
                        facilityId,
                        date
                );

        return ResponseEntity.ok(
                ApiResponse.<List<DailyScheduleResponse>>builder()
                        .success(true)
                        .message("Daily schedule retrieved successfully")
                        .data(result)
                        .build()
        );
    }

    @PostMapping("/{bookingId}/check-in")
    @PreAuthorize("hasRole('STAFF')")
    @Operation(
            summary = "Check-in customer and hand over storage unit"
    )
    public ResponseEntity<ApiResponse<HandoverResponse>> checkIn(
            @PathVariable UUID bookingId,
            @RequestParam UUID facilityId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @Valid HandoverRequest request
    ) {

        HandoverResponse result =
                facilityOperationsService.checkIn(
                        bookingId,
                        facilityId,
                        userDetails.getUsername(),
                        request
                );

        return ResponseEntity.ok(
                ApiResponse.<HandoverResponse>builder()
                        .success(true)
                        .message(result.getMessage())
                        .data(result)
                        .build()
        );
    }

    @PostMapping("/{bookingId}/check-out")
    @PreAuthorize("hasRole('STAFF')")
    @Operation(
            summary = "Inspect returned storage unit and complete check-out"
    )
    public ResponseEntity<ApiResponse<HandoverResponse>> checkOut(
            @PathVariable UUID bookingId,
            @RequestParam UUID facilityId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @Valid HandoverRequest request
    ) {

        HandoverResponse result =
                facilityOperationsService.checkOut(
                        bookingId,
                        facilityId,
                        userDetails.getUsername(),
                        request
                );

        return ResponseEntity.ok(
                ApiResponse.<HandoverResponse>builder()
                        .success(true)
                        .message(result.getMessage())
                        .data(result)
                        .build()
        );
    }

    @PatchMapping("/units/{unitId}/status")
    @PreAuthorize("hasAnyRole('STAFF', 'FACILITY_MANAGER')")
    @Operation(
            summary = "Update storage unit status"
    )
    public ResponseEntity<ApiResponse<String>> updateUnitStatus(
            @PathVariable UUID unitId,
            @RequestParam UUID facilityId,
            @RequestBody @Valid UpdateUnitStatusRequest request
    ) {

        String result =
                facilityOperationsService.updateUnitStatus(
                        unitId,
                        facilityId,
                        request
                );

        return ResponseEntity.ok(
                ApiResponse.<String>builder()
                        .success(true)
                        .message(result)
                        .data(result)
                        .build()
        );
    }
}