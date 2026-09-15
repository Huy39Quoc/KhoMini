package com.storehub.service;

import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.RentalQuoteResponse;

public interface PricingService {
    RentalQuoteResponse calculateRentalQuote(RentalQuoteRequest request);
}