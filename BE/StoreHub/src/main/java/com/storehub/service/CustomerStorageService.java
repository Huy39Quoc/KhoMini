package com.storehub.service;

import com.storehub.dto.request.CheckoutRequest;
import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.ContractOperationResponse;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.SmartAccessResponse;

import java.util.List;
import java.util.UUID;

public interface CustomerStorageService {
    List<MyUnitResponse> getMyRentedUnits(UUID customerId);

    SmartAccessResponse getSmartAccessInfo(Long bookingId, UUID customerId);

    SmartAccessResponse updateAccessPin(Long bookingId, UUID customerId, UpdatePinRequest request);

    // Gia hạn thời gian thuê
    ContractOperationResponse extendRental(Long bookingId, UUID customerId, ExtendRentalRequest request);

    // Gửi yêu cầu hẹn trả kho
    ContractOperationResponse requestCheckout(Long bookingId, UUID customerId, CheckoutRequest request);
}