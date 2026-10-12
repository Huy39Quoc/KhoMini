package com.storehub.dto.response;

import lombok.Builder;
import lombok.Data;

import java.util.UUID;

@Data
@Builder
public class GatePassVerificationResponse {
    private UUID bookingId;
    private String bookingCode;
    private String unitCode;
    private String facilityName;
}
