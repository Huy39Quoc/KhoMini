package com.storehub.entity;

import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "payments")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Payment extends BaseEntity {

    @Column(name = "transaction_id", nullable = false, unique = true, length = 60)
    private String transactionId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id", nullable = false)
    private Booking booking;

    @Column(name = "amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_type", nullable = false, length = 30)
    private PaymentType paymentType;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private PaymentStatus status;

    @Column(name = "payment_method", length = 50)
    private String paymentMethod;

    @Column(name = "payment_time", nullable = false)
    private LocalDateTime paymentTime;

    @Column(name = "note", length = 100)
    private String note;

    // Metadata of the original VNPay payment, required by its refund API.
    @Column(name = "gateway_create_date", length = 14)
    private String gatewayCreateDate;

    @Column(name = "gateway_transaction_no", length = 20)
    private String gatewayTransactionNo;

    @Column(name = "gateway_amount", precision = 12, scale = 2)
    private BigDecimal gatewayAmount;

    @Column(name = "last_gateway_query_at")
    private LocalDateTime lastGatewayQueryAt;

    // A cancelled extension can still be captured by VNPay after its URL is opened.
    @Column(name = "voided_at")
    private LocalDateTime voidedAt;
}
