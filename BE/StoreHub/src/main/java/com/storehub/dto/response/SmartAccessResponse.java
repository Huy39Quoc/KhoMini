package com.storehub.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Trạng thái khóa thông minh của một ngăn kho. Server chỉ lưu PIN dạng băm nên KHÔNG bao giờ
 * trả PIN đã lưu; {@code generatedPin} chỉ có giá trị đúng một lần, ngay lúc hệ thống tạo PIN mới.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SmartAccessResponse {
    private UUID bookingId;
    private String unitCode;
    // Đã có mã PIN hay chưa (chưa có -> khách chọn "hệ thống cấp" hoặc "tự đặt")
    private boolean pinSet;
    private LocalDateTime pinUpdatedAt;
    // true = đang khóa (mặc định, an toàn), false = đang mở
    private boolean locked;
    // Còn bao nhiêu lần nhập sai trước khi bị khóa tạm
    private Integer attemptsRemaining;
    // Có giá trị khi đang bị khóa tạm do nhập sai nhiều lần
    private LocalDateTime pinLockedUntil;
    // PIN do hệ thống tạo - chỉ trả một lần duy nhất ở response của setup/reset
    private String generatedPin;
}
