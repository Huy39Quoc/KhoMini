package com.storehub.dto.response;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class GatePassResponse {
    private UUID bookingId;
    private String facilityName;
    // A short-lived bearer secret; never store or log it in plaintext.
    private String token;
    private String qrPngBase64;
    private Instant expiresAt;
}
