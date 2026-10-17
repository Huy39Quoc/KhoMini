package com.storehub;

import org.junit.jupiter.api.Test;

import java.time.ZoneId;
import java.util.TimeZone;

import static org.junit.jupiter.api.Assertions.assertEquals;

class BusinessTimeZoneTest {
    @Test
    void startupAlignsJvmClockWithBookingBusinessZoneEvenOnUtcHost() {
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("UTC"));
            StoreHubApplication.configureBusinessTimeZone();
            assertEquals(ZoneId.of("Asia/Ho_Chi_Minh"), ZoneId.systemDefault());
        } finally {
            StoreHubApplication.configureBusinessTimeZone();
        }
    }
}
