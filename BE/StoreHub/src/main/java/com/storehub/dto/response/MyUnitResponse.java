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
    private com.storehub.enums.HandoverIssueStatus handoverIssueStatus;
    private String handoverIssueReason;
    private LocalDateTime handoverIssueDueAt;
    private LocalDateTime scheduledCheckInTime;
    private String bookingCode;
    private String facilityName;
    private String facilityAddress;
    private String unitCode;
    private boolean unitAssignmentConfirmed;
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
    private LocalDate pendingNewEndDate;
    private BigDecimal pendingExtensionFee;
    // Ngày bắt đầu được phép gia hạn theo chính sách cơ sở (null nếu không giới hạn)
    private LocalDate renewalOpensDate;

    // --- Quá hạn (điền bởi CustomerStorageServiceImpl) ---
    private boolean overdue;
    private long overdueDays;
    // Tổng phí trễ hạn đang chờ thanh toán (0 nếu không có)
    private BigDecimal overdueFeeOutstanding;
    // true = mã PIN đã bị thu hồi do quá hạn
    private boolean accessDisabled;

    // Lịch hẹn trả kho khách đã gửi (null nếu chưa gửi yêu cầu)
    private LocalDateTime scheduledReturnTime;

    // Giờ hoạt động của cơ sở (để hiển thị và ràng buộc giờ hẹn nhận/trả)
    private java.time.LocalTime openTime;
    private java.time.LocalTime closeTime;
}
