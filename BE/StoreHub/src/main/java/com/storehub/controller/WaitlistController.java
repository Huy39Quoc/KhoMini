package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.service.WaitlistService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/waitlist")
@RequiredArgsConstructor
@Tag(name = "Waitlist", description = "APIs đăng ký hàng đợi khi hết kho trống")
public class WaitlistController {

    private final WaitlistService waitlistService;

    @PostMapping
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Đăng ký vào hàng đợi khi không còn kho trống cho loại kho đã chọn")
    public ResponseEntity<ApiResponse<Void>> joinWaitlist(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam @NotNull UUID facilityId,
            @RequestParam @NotNull UUID unitTypeId
    ) {
        waitlistService.joinWaitlist(userDetails.getUsername(), facilityId, unitTypeId);
        return ResponseEntity.ok(
                ApiResponse.success("You have been added to the waitlist. We will notify you when a unit becomes available.", null));
    }
}
