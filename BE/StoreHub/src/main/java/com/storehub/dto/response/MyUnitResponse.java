package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MyUnitResponse {
    private UUID bookingId;
    private String bookingCode;
    private String facilityName;
    private String facilityAddress;
    private String unitCode;
    private String unitTypeName;
    private String dimensions;
    private Double areaSqm;
    private LocalDate startDate;
    private LocalDate endDate;
    private Integer rentalMonths;
    private BookingStatus status;
    private BigDecimal totalRentalFee;
    private BigDecimal depositPaid;
    private boolean activeAccess;
    private boolean hasPendingExtension;
    private Integer pendingExtraMonths;
    private BigDecimal pendingExtensionFee;

    // --- Quá hạn (điền bởi CustomerStorageServiceImpl) ---
    private boolean overdue;
    private long overdueDays;
    // Tổng phí trễ hạn đang chờ thanh toán (0 nếu không có)
    private BigDecimal overdueFeeOutstanding;
    // true = mã PIN/QR đã bị thu hồi do quá hạn
    private boolean accessDisabled;

    // Lịch hẹn trả kho khách đã gửi (null nếu chưa gửi yêu cầu)
    private LocalDateTime scheduledReturnTime;
}