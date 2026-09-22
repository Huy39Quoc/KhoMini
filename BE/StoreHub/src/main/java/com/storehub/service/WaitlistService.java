package com.storehub.service;

import java.util.UUID;

public interface WaitlistService {

    void joinWaitlist(String customerEmail, UUID facilityId, UUID unitTypeId);

    void notifyNextInWaitlist(UUID facilityId, UUID unitTypeId);
}
