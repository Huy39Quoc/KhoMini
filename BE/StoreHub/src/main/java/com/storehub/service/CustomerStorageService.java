package com.storehub.service;

import com.storehub.dto.request.CheckoutRequest;
import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.ContractOperationResponse;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.dto.response.SmartAccessResponse;

import java.util.List;
import java.util.UUID;

public interface CustomerStorageService {
    List<MyUnitResponse> getMyRentedUnits(String customerEmail);

    SmartAccessResponse getSmartAccessInfo(UUID bookingId, String customerEmail);

    SmartAccessResponse updateAccessPin(UUID bookingId, String customerEmail, UpdatePinRequest request);

    ContractOperationResponse extendRental(UUID bookingId, String customerEmail, ExtendRentalRequest request);

    ContractOperationResponse requestCheckout(UUID bookingId, String customerEmail, CheckoutRequest request);

    PaymentResponse getPendingExtensionPayment(UUID bookingId, String customerEmail);
}