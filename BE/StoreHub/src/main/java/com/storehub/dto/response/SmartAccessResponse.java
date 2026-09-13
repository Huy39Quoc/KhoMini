package com.storehub.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SmartAccessResponse {
    private Long bookingId;
    private String unitCode;
    private String accessPin;
    private String qrCodeToken;
    private LocalDateTime pinUpdatedAt;
    private LocalDateTime tokenExpiresAt;
}