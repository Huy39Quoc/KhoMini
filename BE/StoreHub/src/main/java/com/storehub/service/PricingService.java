package com.storehub.service;

import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.entity.StorageUnit;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

public interface PricingService {

    RentalQuoteResponse calculateRentalQuote(RentalQuoteRequest request);

    BigDecimal calculateExtensionFee(
            StorageUnit storageUnit,
            int extraMonths
    );

    // Phí quản lý theo tháng của cơ sở (cấu hình trong FacilityPolicy; không có chính sách thì dùng mặc định).
    BigDecimal calculateManagementFee(UUID facilityId, int months);

    BigDecimal calculateLateFee(
            UUID facilityId,
            long chargeableDays
    );

    // Nguon tinh coc duy nhat: uu tien % theo FacilityPolicy cua co so, neu co so
    // khong co chinh sach % thi dung defaultDepositAmount (gia coc co dinh cua UnitType).
    // Dung chung cho ca bao gia (PricingServiceImpl) va thu tien thuc te (PaymentServiceImpl)
    // de tranh lech so tien giua luc bao gia va luc thu tien.
    BigDecimal calculateDepositAmount(
            UUID facilityId,
            BigDecimal totalRentalFee,
            BigDecimal defaultDepositAmount
    );

    // Số tiền cọc được hoàn khi khách huỷ đơn đã CONFIRMED, theo bậc chính sách huỷ của cơ sở:
    // >= cancellationFullRefundHours trước giờ nhận kho: hoàn 100%;
    // >= cancellationPartialRefundHours: hoàn cancellationPartialRefundPercent%; còn lại: 0.
    BigDecimal calculateCancellationRefund(
            UUID facilityId,
            BigDecimal depositPaid,
            LocalDateTime scheduledStart,
            LocalDateTime cancelTime
    );
}
