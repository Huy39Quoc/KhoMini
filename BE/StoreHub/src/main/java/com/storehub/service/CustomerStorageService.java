package com.storehub.service;

import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.SmartAccessResponse;

import java.util.List;
import java.util.UUID;

public interface CustomerStorageService {
    List<MyUnitResponse> getMyRentedUnits(UUID customerId);

    // Lấy thông tin mã PIN & QR Code của kho
    SmartAccessResponse getSmartAccessInfo(Long bookingId, UUID customerId);

    // Đổi mã PIN mới cho kho
    SmartAccessResponse updateAccessPin(Long bookingId, UUID customerId, UpdatePinRequest request);
}