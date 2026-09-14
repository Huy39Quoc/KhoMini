package com.storehub.dto.response;

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
public class SmartAccessResponse {
    private UUID bookingId;
    private String unitCode;
    private String accessPin;
    private String qrCodeToken;
    private LocalDateTime pinUpdatedAt;
    private LocalDateTime tokenExpiresAt;
}