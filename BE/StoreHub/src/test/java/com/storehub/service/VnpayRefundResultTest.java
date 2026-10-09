package com.storehub.service;

import com.storehub.service.impl.VnpayRefundClient.GatewayResult;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class VnpayRefundResultTest {
    @Test
    void acceptedRequestIsNotAccountedAsRefundedUntilGatewayConfirmsAmountAndStatus() {
        BigDecimal requested = new BigDecimal("100000");
        assertFalse(new GatewayResult("00", "05", "03", "10000000").confirmed(requested));
        assertFalse(new GatewayResult("00", "00", "03", "9999999").confirmed(requested));
        assertFalse(new GatewayResult("00", "00", "01", "10000000").confirmed(requested));
        assertTrue(new GatewayResult("00", "00", "03", "10000000").confirmed(requested));
    }
}
