package com.storehub.service;

import java.util.UUID;
import java.util.List;
import com.storehub.dto.response.WaitlistResponse;

public interface WaitlistService {

    void joinWaitlist(String customerEmail, UUID facilityId, UUID unitTypeId);

    void notifyNextInWaitlist(UUID facilityId, UUID unitTypeId);

    void expireStaleNotifications();

    void markFulfilled(UUID customerId, UUID facilityId, UUID unitTypeId);

    List<WaitlistResponse> myWaitlist(String customerEmail);

    void leaveWaitlist(String customerEmail, UUID waitlistId);
}
