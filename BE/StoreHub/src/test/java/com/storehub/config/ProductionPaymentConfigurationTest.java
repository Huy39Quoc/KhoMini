package com.storehub.config;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ProductionPaymentConfigurationTest {
    @Test
    void rejectsEmulatorAndSandboxInProduction() {
        assertThrows(IllegalStateException.class, () -> new ProductionPaymentConfiguration(
                "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html",
                "https://gateway.example.com/transaction",
                "http://10.0.2.2:8080/api/v1/payments/vnpay-return",
                "https://app.example.com", "203.0.113.4", "merchant123", "secret")
                .afterPropertiesSet());
    }

    @Test
    void requiresCorrectReturnPathAndPublicMerchantIp() {
        assertThrows(IllegalStateException.class, () -> new ProductionPaymentConfiguration(
                "https://pay.example.com/pay", "https://pay.example.com/transaction",
                "https://api.example.com/wrong", "https://app.example.com", "203.0.113.4",
                "merchant123", "secret")
                .afterPropertiesSet());
        assertThrows(IllegalStateException.class, () -> new ProductionPaymentConfiguration(
                "https://pay.example.com/pay", "https://pay.example.com/transaction",
                "https://api.example.com/api/v1/payments/vnpay-return", "https://app.example.com",
                "127.0.0.1", "merchant123", "secret").afterPropertiesSet());
        assertDoesNotThrow(() -> new ProductionPaymentConfiguration(
                "https://pay.example.com/pay", "https://pay.example.com/transaction",
                "https://api.example.com/api/v1/payments/vnpay-return", "https://app.example.com",
                "203.0.113.4", "merchant123", "secret").afterPropertiesSet());
    }
}
