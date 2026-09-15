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
    // customerEmail: lấy trực tiếp từ Authentication (email đăng nhập),
    // việc tra ra UUID thật của user được xử lý bên trong Impl (đúng layer Service).
    List<MyUnitResponse> getMyRentedUnits(String customerEmail);

    SmartAccessResponse getSmartAccessInfo(UUID bookingId, String customerEmail);

    SmartAccessResponse updateAccessPin(UUID bookingId, String customerEmail, UpdatePinRequest request);

    // Gia hạn thời gian thuê
    ContractOperationResponse extendRental(UUID bookingId, String customerEmail, ExtendRentalRequest request);

    // Gửi yêu cầu hẹn trả kho
    ContractOperationResponse requestCheckout(UUID bookingId, String customerEmail, CheckoutRequest request);
}