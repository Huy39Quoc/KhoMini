package com.storehub.exception;

/** Keep newly accrued debt when checkout is refused; other errors still roll back. */
public class OutstandingOverdueFeeException extends AppException {
    public OutstandingOverdueFeeException() {
        super(ErrorCode.OVERDUE_FEE_UNPAID_ON_RETURN);
    }
}
