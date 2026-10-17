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

    @NotNull(message = "Vui lòng chọn giờ hẹn trả kho")
    @Future(message = "Giờ hẹn trả kho phải ở tương lai")
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