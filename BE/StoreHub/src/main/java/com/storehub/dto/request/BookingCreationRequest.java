package com.storehub.dto.request;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BookingCreationRequest {

    @NotNull(message = "Facility ID is required")
    private UUID facilityId;

    @NotNull(message = "Unit type ID is required")
    private UUID unitTypeId;

    @NotNull(message = "Start date is required")
    @FutureOrPresent(message = "Start date cannot be in the past")
    private LocalDate startDate;

    // Giờ hẹn nhận kho tại chi nhánh; nếu không gửi, dùng giờ mở cửa.
    private LocalTime checkInTime;

    @NotNull(message = "Rental months is required")
    @Min(value = 1, message = "Rental months must be at least 1")
    @Max(value = 36, message = "Rental months must be at most 36")
    private Integer rentalMonths;

    // Cam kết không lưu trữ hàng cấm
    @NotNull(message = "Prohibited items confirmation is required")
    @jakarta.validation.constraints.AssertTrue(message = "You must confirm you will not store prohibited items")
    private Boolean prohibitedItemsConfirmed;

    // Chấp thuận điều khoản dịch vụ lưu kho
    @NotNull(message = "Terms and conditions confirmation is required")
    @jakarta.validation.constraints.AssertTrue(message = "You must accept the terms of service")
    private Boolean termsConfirmed;

    // Phiên bản điều khoản đã chấp thuận
    private String termsVersion;
}
