package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.dto.request.BookingCreationRequest;
import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.BookingResponse;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.service.BookingService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/bookings")
@RequiredArgsConstructor
@Tag(name = "Booking", description = "APIs đặt chỗ và quản lý đơn thuê kho")
public class BookingController {

    private final BookingService bookingService;

    @PostMapping("/quote")
    @Operation(summary = "Tính báo giá thuê kho (không tạo booking)")
    public ResponseEntity<ApiResponse<RentalQuoteResponse>> getRentalQuote(
            @Valid @RequestBody RentalQuoteRequest request
    ) {
        RentalQuoteResponse quote = bookingService.getRentalQuote(request);
        return ResponseEntity.ok(ApiResponse.success("Rental quote calculated successfully", quote));
    }

    @PostMapping
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Tạo đơn đặt chỗ kho mới (trạng thái PENDING_PAYMENT, hết hạn sau 30 phút)")
    public ResponseEntity<ApiResponse<BookingResponse>> createBooking(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody BookingCreationRequest request
    ) {
        BookingResponse booking = bookingService.createBooking(userDetails.getUsername(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("Booking created successfully. Please complete payment to confirm.", booking));
    }

    @DeleteMapping("/{id}")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Hủy đơn đặt chỗ đang PENDING_PAYMENT – trả kho về AVAILABLE và notify waitlist")
    public ResponseEntity<ApiResponse<Void>> cancelBooking(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable UUID id
    ) {
        bookingService.cancelBooking(id, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success("Booking cancelled successfully", null));
    }
}
