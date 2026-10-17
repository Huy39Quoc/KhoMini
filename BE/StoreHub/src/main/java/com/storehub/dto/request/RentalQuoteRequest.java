package com.storehub.dto.request;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RentalQuoteRequest {

    private UUID unitTypeId;
    private UUID storageUnitId;

    // Tuỳ chọn: khi báo giá theo unitTypeId, truyền thêm facilityId để tiền cọc được
    // tính theo % chính sách của cơ sở (khớp với số tiền thu thực tế ở PaymentService).
    private UUID facilityId;

    @NotNull(message = "Vui lòng chọn ngày bắt đầu")
    @FutureOrPresent(message = "Ngày bắt đầu phải từ hôm nay trở đi")
    private LocalDate startDate;

    @NotNull(message = "Vui lòng chọn số tháng thuê")
    @Min(value = 1, message = "Thời gian thuê tối thiểu 1 tháng")
    @Max(value = 36, message = "Thời gian thuê tối đa 36 tháng")
    private Integer rentalMonths;
}