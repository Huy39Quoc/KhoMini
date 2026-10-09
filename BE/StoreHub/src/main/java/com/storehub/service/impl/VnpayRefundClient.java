package com.storehub.service.impl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.storehub.util.VNPayUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;

@Component
public class VnpayRefundClient {
    private static final DateTimeFormatter FORMAT = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");
    private static final ZoneId VIETNAM = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final String[] REFUND_SIGNATURE = {
            "vnp_ResponseId", "vnp_Command", "vnp_ResponseCode", "vnp_Message",
            "vnp_TmnCode", "vnp_TxnRef", "vnp_Amount", "vnp_BankCode",
            "vnp_PayDate", "vnp_TransactionNo", "vnp_TransactionType",
            "vnp_TransactionStatus", "vnp_OrderInfo"
    };

    private final ObjectMapper mapper;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10)).build();

    @Value("${vnpay.transaction-url}") private String transactionUrl;
    @Value("${vnpay.tmn-code}") private String tmnCode;
    @Value("${vnpay.hash-secret}") private String secret;
    @Value("${vnpay.merchant-ip}") private String merchantIp;

    public VnpayRefundClient(ObjectMapper mapper) {
        this.mapper = mapper;
    }

    public GatewayResult refund(String requestId, String txnRef, String txnDate,
                                String txnNo, BigDecimal originalAmount,
                                BigDecimal amount, String bookingCode) throws Exception {
        if (txnDate == null) {
            throw new IllegalStateException("Original VNPay payment date is unavailable; manual reconciliation required");
        }
        Map<String, String> body = new LinkedHashMap<>();
        body.put("vnp_RequestId", requestId);
        body.put("vnp_Version", "2.1.0");
        body.put("vnp_Command", "refund");
        body.put("vnp_TmnCode", tmnCode);
        body.put("vnp_TransactionType", originalAmount != null
                && originalAmount.compareTo(amount) == 0 ? "02" : "03");
        body.put("vnp_TxnRef", txnRef);
        body.put("vnp_Amount", amount.movePointRight(2).toBigIntegerExact().toString());
        body.put("vnp_TransactionNo", txnNo == null ? "" : txnNo);
        body.put("vnp_TransactionDate", txnDate);
        body.put("vnp_CreateBy", "StoreHub");
        body.put("vnp_CreateDate", LocalDateTime.now(VIETNAM).format(FORMAT));
        body.put("vnp_IpAddr", merchantIp);
        body.put("vnp_OrderInfo", "Refund booking " + bookingCode);
        body.put("vnp_SecureHash", VNPayUtil.hmacSHA512(secret, String.join("|", body.values())));
        return postAndVerify(body, REFUND_SIGNATURE);
    }

    public GatewayResult query(String txnRef, String txnDate) throws Exception {
        Map<String, String> body = new LinkedHashMap<>();
        body.put("vnp_RequestId", java.util.UUID.randomUUID().toString().replace("-", ""));
        body.put("vnp_Version", "2.1.0");
        body.put("vnp_Command", "querydr");
        body.put("vnp_TmnCode", tmnCode);
        body.put("vnp_TxnRef", txnRef);
        body.put("vnp_TransactionDate", txnDate);
        body.put("vnp_CreateDate", LocalDateTime.now(VIETNAM).format(FORMAT));
        body.put("vnp_IpAddr", merchantIp);
        body.put("vnp_OrderInfo", "Query refund " + txnRef);
        body.put("vnp_SecureHash", VNPayUtil.hmacSHA512(secret, String.join("|", body.values())));
        return postAndVerify(body, new String[] {
                "vnp_ResponseId", "vnp_Command", "vnp_ResponseCode", "vnp_Message",
                "vnp_TmnCode", "vnp_TxnRef", "vnp_Amount", "vnp_BankCode",
                "vnp_PayDate", "vnp_TransactionNo", "vnp_TransactionType",
                "vnp_TransactionStatus", "vnp_OrderInfo", "vnp_PromotionCode", "vnp_PromotionAmount"
        });
    }

    private GatewayResult postAndVerify(Map<String, String> body, String[] signatureFields) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create(transactionUrl))
                .timeout(Duration.ofSeconds(20))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(body)))
                .build();
        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IllegalStateException("VNPay refund HTTP " + response.statusCode());
        }
        JsonNode json = mapper.readTree(response.body());
        StringBuilder signed = new StringBuilder();
        for (String key : signatureFields) {
            if (signed.length() > 0) signed.append('|');
            signed.append(json.path(key).asText(""));
        }
        String actualHash = json.path("vnp_SecureHash").asText("");
        if (actualHash.isBlank() || !VNPayUtil.hmacSHA512(secret, signed.toString()).equalsIgnoreCase(actualHash)
                || !body.get("vnp_Command").equals(json.path("vnp_Command").asText())
                || !tmnCode.equals(json.path("vnp_TmnCode").asText())
                || !body.get("vnp_TxnRef").equals(json.path("vnp_TxnRef").asText())
                || (body.containsKey("vnp_Amount") && !body.get("vnp_Amount")
                        .equals(json.path("vnp_Amount").asText()))) {
            throw new IllegalStateException("Invalid VNPay refund response signature or transaction");
        }
        return new GatewayResult(json.path("vnp_ResponseCode").asText(),
                json.path("vnp_TransactionStatus").asText(),
                json.path("vnp_TransactionType").asText(),
                json.path("vnp_Amount").asText());
    }

    public record GatewayResult(String responseCode, String transactionStatus,
                                String transactionType, String amount) {
        public boolean confirmed(BigDecimal requestedAmount) {
            boolean matches;
            try {
                matches = new BigDecimal(amount).compareTo(requestedAmount.movePointRight(2)) == 0;
            } catch (NumberFormatException e) {
                matches = false;
            }
            return "00".equals(responseCode) && "00".equals(transactionStatus)
                    && ("02".equals(transactionType) || "03".equals(transactionType)) && matches;
        }
    }
}
