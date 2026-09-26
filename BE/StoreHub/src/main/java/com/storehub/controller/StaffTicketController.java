package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.UpdateStaffTicketStatusRequest;
import com.storehub.dto.response.TicketResponse;
import com.storehub.service.StaffTicketService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/staff/tickets")
@RequiredArgsConstructor
@Tag(name = "Staff Support Tickets", description = "API để nhân viên cơ sở xử lý ticket")
@SecurityRequirement(name = "Bearer Authentication")
public class StaffTicketController {

    private final StaffTicketService staffTicketService;

    @GetMapping
    @PreAuthorize("hasRole('STAFF')")
    @Operation(summary = "Lấy danh sách ticket thuộc cơ sở của staff")
    public ResponseEntity<ApiResponse<PageResponse<TicketResponse>>> getFacilityTickets(
            @RequestParam UUID facilityId,
            @AuthenticationPrincipal UserDetails userDetails,
            @ParameterObject
            @PageableDefault(sort = "createdAt", direction = Sort.Direction.DESC)
            Pageable pageable
    ) {
        PageResponse<TicketResponse> response = staffTicketService.getFacilityTickets(
                facilityId,
                userDetails.getUsername(),
                pageable
        );

        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/{ticketId}/assign-to-me")
    @PreAuthorize("hasRole('STAFF')")
    @Operation(summary = "Staff tự nhận xử lý ticket")
    public ResponseEntity<ApiResponse<TicketResponse>> assignToMe(
            @RequestParam UUID facilityId,
            @PathVariable UUID ticketId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        TicketResponse response = staffTicketService.assignToMe(
                facilityId,
                ticketId,
                userDetails.getUsername()
        );

        return ResponseEntity.ok(
                ApiResponse.success("Ticket assigned successfully", response)
        );
    }

    @PatchMapping("/{ticketId}/status")
    @PreAuthorize("hasRole('STAFF')")
    @Operation(summary = "Cập nhật trạng thái xử lý ticket")
    public ResponseEntity<ApiResponse<TicketResponse>> updateStatus(
            @RequestParam UUID facilityId,
            @PathVariable UUID ticketId,
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody UpdateStaffTicketStatusRequest request
    ) {
        TicketResponse response = staffTicketService.updateStatus(
                facilityId,
                ticketId,
                userDetails.getUsername(),
                request
        );

        return ResponseEntity.ok(
                ApiResponse.success("Ticket updated successfully", response)
        );
    }
}