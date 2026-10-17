package com.storehub.dto.request;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CheckoutRequest {

    @NotNull(message = "Scheduled return time cannot be null")
    @Future(message = "Scheduled return time must be in the future")
    private LocalDateTime scheduledReturnTime;

    private String notes;

    private String bankCode;
    private String bankAccountNumber;
    private String bankAccountName;

    public String getRefundBankCode() {
        return bankCode;
    }

    public void setRefundBankCode(String refundBankCode) {
        this.bankCode = refundBankCode;
    }

    public String getRefundAccountNumber() {
        return bankAccountNumber;
    }

    public void setRefundAccountNumber(String refundAccountNumber) {
        this.bankAccountNumber = refundAccountNumber;
    }

    public String getRefundAccountName() {
        return bankAccountName;
    }

    public void setRefundAccountName(String refundAccountName) {
        this.bankAccountName = refundAccountName;
    }
}