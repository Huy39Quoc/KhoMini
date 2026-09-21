package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.CreateTicketRequest;
import com.storehub.dto.response.TicketResponse;
import com.storehub.service.CustomerTicketService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springdoc.core.annotations.ParameterObject;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/customer/tickets")
@RequiredArgsConstructor
@Tag(name = "Customer Support Tickets", description = "APIs gửi và theo dõi yêu cầu hỗ trợ kỹ thuật")
@SecurityRequirement(name = "Bearer Authentication")
public class CustomerTicketController {

    private final CustomerTicketService customerTicketService;

    @PostMapping
    @PreAuthorize("hasRole('CUSTOMER')")
    @Operation(summary = "Tạo mới một yêu cầu hỗ trợ sự cố kho")
    public ResponseEntity<ApiResponse<TicketResponse>> createTicket(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @Valid CreateTicketRequest request
    ) {
        TicketResponse response = customerTicketService.createTicket(userDetails.getUsername(), request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.<TicketResponse>builder()
                .success(true)
                .message("Support ticket submitted successfully")
                .data(response)
                .build());
    }

    @GetMapping
    @PreAuthorize("hasRole('CUSTOMER')")
    @Operation(summary = "Lấy danh sách các yêu cầu hỗ trợ của khách hàng (có phân trang)")
    public ResponseEntity<ApiResponse<PageResponse<TicketResponse>>> getMyTickets(
            @AuthenticationPrincipal UserDetails userDetails,
            @ParameterObject @PageableDefault(sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable
    ) {
        PageResponse<TicketResponse> response = customerTicketService.getMyTickets(userDetails.getUsername(), pageable);
        return ResponseEntity.ok(ApiResponse.<PageResponse<TicketResponse>>builder()
                .success(true)
                .message("Support tickets retrieved successfully")
                .data(response)
                .build());
    }

    @GetMapping("/{ticketId}")
    @PreAuthorize("hasRole('CUSTOMER')")
    @Operation(summary = "Xem chi tiết tiến trình xử lý của một yêu cầu hỗ trợ")
    public ResponseEntity<ApiResponse<TicketResponse>> getTicketDetail(
            @PathVariable UUID ticketId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        TicketResponse response = customerTicketService.getTicketDetail(ticketId, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.<TicketResponse>builder()
                .success(true)
                .message("Ticket details retrieved successfully")
                .data(response)
                .build());
    }
}