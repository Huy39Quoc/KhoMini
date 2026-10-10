package com.storehub.service;

import com.storehub.dto.response.GatePassResponse;
import com.storehub.dto.response.GatePassVerificationResponse;

import java.util.UUID;

public interface GatePassService {
    GatePassResponse issue(UUID bookingId, String customerEmail);

    GatePassVerificationResponse verify(String staffEmail, UUID facilityId, String token);
}
