# VNPay refund flow

The original booking payment combines the deposit and rental fee into a single
VNPay transaction. A return requests a deposit refund. A cancellation requests
the policy amount, allocating it to the deposit first and then rent. Neither
action reports the money as refunded immediately.

After the booking transaction commits, `RefundDispatcher` sends queued requests
to VNPay's refund API (`VNPAY_TRANSACTION_URL`). A signed gateway response with
refund type, amount and successful transaction status marks the refund complete;
an accepted but unsettled request stays `AWAITING_CONFIRMATION`. The dispatcher
queries VNPay again after six minutes. Network ambiguity, invalid signatures,
and crashed in-flight requests require review; the dispatcher never resends
them automatically.

The facility manager's **Refund requests** screen shows the latest requests.
For payments made before migration V14, find the original transaction in the
VNPay merchant portal and enter its original create date (`yyyyMMddHHmmss`),
VNPay transaction number if available, and original total amount in VND.
Those values are required by VNPay's refund API. `NEEDS_REVIEW` can be checked
against VNPay using **Check with VNPay**; only a definitively `REJECTED` request
can be retried with a new request ID. Reconcile ambiguous cases in the merchant
portal before any manual action.

Set `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`, and, if needed,
`VNPAY_TRANSACTION_URL`, and `VNPAY_MERCHANT_IP` for your server. Exercise a paid booking, check-out and cancellation in
the VNPay sandbox. Verify both the signed gateway response and the merchant
portal before treating a refund as settled.

Official API specification:
https://sandbox.vnpayment.vn/apis/docs/truy-van-hoan-tien/querydr&refund.html
