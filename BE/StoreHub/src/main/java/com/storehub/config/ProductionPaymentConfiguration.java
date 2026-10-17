package com.storehub.config;

import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.net.URI;

/** Refuse to start a production server with emulator or sandbox payment endpoints. */
@Component
@Profile("prod")
public class ProductionPaymentConfiguration implements InitializingBean {
    private final String paymentUrl;
    private final String transactionUrl;
    private final String returnUrl;
    private final String frontendUrl;
    private final String merchantIp;
    private final String tmnCode;
    private final String hashSecret;

    public ProductionPaymentConfiguration(
            @Value("${vnpay.url}") String paymentUrl,
            @Value("${vnpay.transaction-url}") String transactionUrl,
            @Value("${vnpay.return-url}") String returnUrl,
            @Value("${app.frontend-url}") String frontendUrl,
            @Value("${vnpay.merchant-ip}") String merchantIp,
            @Value("${vnpay.tmn-code}") String tmnCode,
            @Value("${vnpay.hash-secret}") String hashSecret) {
        this.paymentUrl = paymentUrl;
        this.transactionUrl = transactionUrl;
        this.returnUrl = returnUrl;
        this.frontendUrl = frontendUrl;
        this.merchantIp = merchantIp;
        this.tmnCode = tmnCode;
        this.hashSecret = hashSecret;
    }

    @Override
    public void afterPropertiesSet() {
        if (tmnCode == null || tmnCode.isBlank() || hashSecret == null || hashSecret.isBlank()) {
            throw new IllegalStateException("VNPAY_TMN_CODE and VNPAY_HASH_SECRET are required");
        }
        requirePublicHttps("VNPAY_URL", paymentUrl);
        requirePublicHttps("VNPAY_TRANSACTION_URL", transactionUrl);
        requirePublicHttps("VNPAY_RETURN_URL", returnUrl);
        requirePublicHttps("APP_FRONTEND_URL", frontendUrl);
        if (!URI.create(returnUrl).getPath().equals("/api/v1/payments/vnpay-return")) {
            throw new IllegalStateException("VNPAY_RETURN_URL must point to /api/v1/payments/vnpay-return");
        }
        if (merchantIp.isBlank() || merchantIp.equals("127.0.0.1") || merchantIp.equals("::1")) {
            throw new IllegalStateException("VNPAY_MERCHANT_IP must be the configured public server IP");
        }
    }

    static void requirePublicHttps(String name, String value) {
        URI uri;
        try {
            uri = URI.create(value);
        } catch (RuntimeException e) {
            throw new IllegalStateException(name + " must be a valid HTTPS URL", e);
        }
        String host = uri.getHost();
        if (!"https".equalsIgnoreCase(uri.getScheme()) || host == null
                || host.equalsIgnoreCase("localhost") || host.equals("10.0.2.2")
                || host.startsWith("127.") || host.endsWith(".localhost")
                || host.equalsIgnoreCase("sandbox.vnpayment.vn")) {
            throw new IllegalStateException(name + " must be a public HTTPS URL outside VNPay sandbox");
        }
    }
}
