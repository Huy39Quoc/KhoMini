package com.storehub.service;

import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.entity.StorageUnit;

import java.math.BigDecimal;

public interface PricingService {
    RentalQuoteResponse calculateRentalQuote(RentalQuoteRequest request);

    BigDecimal calculateExtensionFee(StorageUnit storageUnit, int extraMonths);
}