package com.storehub.entity;

import com.storehub.enums.RefundStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "refund_requests")
@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
public class RefundRequest extends BaseEntity {
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "booking_id", nullable = false, unique = true)
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "original_payment_id", nullable = false)
    private Payment originalPayment;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "refund_payment_id", nullable = false, unique = true)
    private Payment refundPayment;

    @Column(name = "request_id", nullable = false, unique = true, length = 32)
    private String requestId;

    @Column(name = "amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(name = "deposit_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal depositAmount;

    @Column(name = "rental_amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal rentalAmount;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private RefundStatus status;

    @Column(name = "gateway_response_code", length = 10)
    private String gatewayResponseCode;

    @Column(name = "gateway_transaction_status", length = 10)
    private String gatewayTransactionStatus;

    @Column(name = "updated_status_at")
    private LocalDateTime updatedStatusAt;
}
