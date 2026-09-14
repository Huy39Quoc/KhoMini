package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.CreateTicketRequest;
import com.storehub.dto.response.TicketResponse;
import com.storehub.entity.User;
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
import org.springframework.security.core.annotation.AuthenticationPrincipal;
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
    @Operation(summary = "Tạo mới một yêu cầu hỗ trợ sự cố kho")
    public ResponseEntity<ApiResponse<TicketResponse>> createTicket(
            @AuthenticationPrincipal User currentUser,
            @RequestBody @Valid CreateTicketRequest request
    ) {
        TicketResponse response = customerTicketService.createTicket(currentUser, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.<TicketResponse>builder()
                .success(true)
                .message("Support ticket submitted successfully")
                .data(response)
                .build());
    }

    @GetMapping
    @Operation(summary = "Lấy danh sách các yêu cầu hỗ trợ của khách hàng (có phân trang)")
    public ResponseEntity<ApiResponse<PageResponse<TicketResponse>>> getMyTickets(
            @AuthenticationPrincipal User currentUser,
            @ParameterObject @PageableDefault(sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable
    ) {
        PageResponse<TicketResponse> response = customerTicketService.getMyTickets(currentUser, pageable);
        return ResponseEntity.ok(ApiResponse.<PageResponse<TicketResponse>>builder()
                .success(true)
                .message("Support tickets retrieved successfully")
                .data(response)
                .build());
    }

    @GetMapping("/{ticketId}")
    @Operation(summary = "Xem chi tiết tiến trình xử lý của một yêu cầu hỗ trợ")
    public ResponseEntity<ApiResponse<TicketResponse>> getTicketDetail(
            @PathVariable UUID ticketId,
            @AuthenticationPrincipal User currentUser
    ) {
        TicketResponse response = customerTicketService.getTicketDetail(ticketId, currentUser);
        return ResponseEntity.ok(ApiResponse.<TicketResponse>builder()
                .success(true)
                .message("Ticket details retrieved successfully")
                .data(response)
                .build());
    }
}