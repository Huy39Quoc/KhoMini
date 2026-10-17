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

    @NotNull(message = "Vui lòng chọn cơ sở")
    private UUID facilityId;

    @NotNull(message = "Vui lòng chọn loại kho")
    private UUID unitTypeId;

    @NotNull(message = "Vui lòng chọn ngày bắt đầu")
    @FutureOrPresent(message = "Ngày bắt đầu không được ở quá khứ")
    private LocalDate startDate;

    // Giờ hẹn nhận kho tại chi nhánh; nếu không gửi, dùng giờ mở cửa.
    private LocalTime checkInTime;

    @NotNull(message = "Vui lòng chọn số tháng thuê")
    @Min(value = 1, message = "Thời gian thuê tối thiểu 1 tháng")
    @Max(value = 36, message = "Thời gian thuê tối đa 36 tháng")
    private Integer rentalMonths;

    // Cam kết không lưu trữ hàng cấm
    @NotNull(message = "Bạn cần cam kết không lưu trữ hàng cấm")
    @jakarta.validation.constraints.AssertTrue(message = "You must confirm you will not store prohibited items")
    private Boolean prohibitedItemsConfirmed;

    // Chấp thuận điều khoản dịch vụ lưu kho
    @NotNull(message = "Bạn cần đồng ý điều khoản thuê kho")
    @jakarta.validation.constraints.AssertTrue(message = "You must accept the terms of service")
    private Boolean termsConfirmed;

    // Phiên bản điều khoản đã chấp thuận
    private String termsVersion;
}
