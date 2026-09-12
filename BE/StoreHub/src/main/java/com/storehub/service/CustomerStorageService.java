package com.storehub.service;

import com.storehub.dto.response.MyUnitResponse;
import java.util.List;
import java.util.UUID;

public interface CustomerStorageService {
    List<MyUnitResponse> getMyRentedUnits(UUID customerId);
}