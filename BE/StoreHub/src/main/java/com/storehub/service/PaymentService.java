package com.storehub.service;

import com.storehub.dto.request.PaymentConfirmationRequest;
import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;

import java.util.UUID;

public interface PaymentService {

    PaymentResponse initiatePayment(
            String customerEmail,
            PaymentInitiationRequest request
    );

    PaymentResponse confirmPayment(
            PaymentConfirmationRequest request
    );

    PaymentResponse getPendingExtensionPayment(
            String customerEmail,
            UUID bookingId
    );

    PaymentResponse getPendingOverduePayment(
            String customerEmail,
            UUID bookingId
    );
}