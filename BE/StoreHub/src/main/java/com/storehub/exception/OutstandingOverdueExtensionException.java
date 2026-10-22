package com.storehub.exception;

/** Commit a newly accrued fee even when the extension request is refused. */
public class OutstandingOverdueExtensionException extends AppException {
    public OutstandingOverdueExtensionException() {
        super(ErrorCode.OVERDUE_FEE_UNPAID);
    }
}
