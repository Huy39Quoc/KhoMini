package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DailyScheduleResponse {

    private UUID bookingId;

    private String bookingCode;

    private UUID customerId;

    private String customerName;

    private String customerEmail;

    private UUID facilityId;

    private String facilityName;

    private UUID storageUnitId;

    private String unitCode;

    private String floorLevel;

    private String type;

    private LocalDateTime scheduledTime;

    private String scheduleType;

    private UUID assignedStaffId;

    private String assignedStaffName;

    private BookingStatus bookingStatus;

    // Quản lý cơ sở đã xác nhận ngăn kho vật lý hay chưa (bắt buộc trước khi bàn giao).
    private Boolean unitAssignmentConfirmed;
}
