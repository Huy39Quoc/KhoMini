package com.storehub.service.impl;

import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.FeeItemResponse;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.FacilityPolicy;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.UnitType;
import com.storehub.enums.RentalFeeType;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.service.PricingService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.storehub.service.FacilityPolicyService;
import java.util.UUID;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.DecimalFormat;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PricingServiceImpl implements PricingService {

    private static final BigDecimal STANDARD_MANAGEMENT_FEE = BigDecimal.valueOf(50000).setScale(0, RoundingMode.UNNECESSARY);
    private static final BigDecimal ONE_HUNDRED = BigDecimal.valueOf(100);
    private static final DecimalFormat CURRENCY_FORMAT = new DecimalFormat("#,###");
    private final FacilityPolicyService facilityPolicyService;
    private final UnitTypeRepository unitTypeRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final FacilityPolicyRepository facilityPolicyRepository;
    private final FacilityRepository facilityRepository;

    @Override
    @Transactional(readOnly = true)
    public RentalQuoteResponse calculateRentalQuote(RentalQuoteRequest request) {
        boolean hasUnitType = request.getUnitTypeId() != null;
        boolean hasStorageUnit = request.getStorageUnitId() != null;

        if (hasUnitType == hasStorageUnit) {
            throw new AppException(ErrorCode.INVALID_PRICING_TARGET);
        }

        UnitType unitType;
        StorageUnit storageUnit = null;
        Facility facility = null;

        if (hasStorageUnit) {
            storageUnit = storageUnitRepository.findWithDetailsById(request.getStorageUnitId())
                    .orElseThrow(() -> new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND));
            unitType = storageUnit.getUnitType();
            facility = storageUnit.getFacility();
        } else {
            unitType = unitTypeRepository.findById(request.getUnitTypeId())
                    .orElseThrow(() -> new AppException(ErrorCode.UNIT_TYPE_NOT_FOUND));
            if (request.getFacilityId() != null) {
                facility = facilityRepository.findById(request.getFacilityId())
                        .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));
            }
        }

        if (unitType.getBasePricePerMonth() == null) {
            throw new AppException(ErrorCode.UNIT_TYPE_PRICE_NOT_CONFIGURED);
        }

        int months = request.getRentalMonths();
        LocalDate startDate = request.getStartDate();
        LocalDate endDate = startDate.plusMonths(months);

        BigDecimal monthlyRate = unitType.getBasePricePerMonth().setScale(0, RoundingMode.HALF_UP);
        BigDecimal totalRentalFee = monthlyRate.multiply(BigDecimal.valueOf(months)).setScale(0, RoundingMode.HALF_UP);

        BigDecimal defaultDeposit = (unitType.getDepositAmount() != null)
                ? unitType.getDepositAmount().setScale(0, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        UUID facilityIdForDeposit = facility != null ? facility.getId() : null;
        BigDecimal depositAmount = calculateDepositAmount(facilityIdForDeposit, totalRentalFee, defaultDeposit);

        BigDecimal totalManagementFee = STANDARD_MANAGEMENT_FEE.multiply(BigDecimal.valueOf(months)).setScale(0, RoundingMode.HALF_UP);
        BigDecimal totalExtraFees = totalManagementFee;

        BigDecimal initialPayment = totalRentalFee.add(depositAmount).add(totalExtraFees);

        List<FeeItemResponse> breakdown = new ArrayList<>();
        breakdown.add(FeeItemResponse.builder()
                .feeType(RentalFeeType.RENTAL_FEE)
                .name("Tiền thuê kho")
                .unitPrice(monthlyRate)
                .quantity(months)
                .totalAmount(totalRentalFee)
                .note("Đơn giá: " + CURRENCY_FORMAT.format(monthlyRate) + " VNĐ / tháng")
                .build());

        breakdown.add(FeeItemResponse.builder()
                .feeType(RentalFeeType.DEPOSIT)
                .name("Tiền đặt cọc bảo đảm")
                .unitPrice(depositAmount)
                .quantity(1)
                .totalAmount(depositAmount)
                .note(depositAmount.compareTo(BigDecimal.ZERO) == 0
                        ? "Áp dụng chính sách miễn tiền cọc"
                        : "Khoản đặt cọc hoàn lại khi hoàn tất trả kho")
                .build());

        breakdown.add(FeeItemResponse.builder()
                .feeType(RentalFeeType.MANAGEMENT_FEE)
                .name("Phí vận hành và quản lý tiện ích")
                .unitPrice(STANDARD_MANAGEMENT_FEE)
                .quantity(months)
                .totalAmount(totalManagementFee)
                .note("Đơn giá: " + CURRENCY_FORMAT.format(STANDARD_MANAGEMENT_FEE) + " VNĐ / tháng")
                .build());

        return RentalQuoteResponse.builder()
                .unitTypeId(unitType.getId())
                .unitTypeName(unitType.getTypeName())
                .dimensions(unitType.getDimensions())
                .areaSqm(unitType.getAreaSqm())
                .storageUnitId(storageUnit != null ? storageUnit.getId() : null)
                .unitCode(storageUnit != null ? storageUnit.getUnitCode() : null)
                .facilityId(facility != null ? facility.getId() : null)
                .facilityName(facility != null ? facility.getName() : null)
                .startDate(startDate)
                .endDate(endDate)
                .rentalMonths(months)
                .basePricePerMonth(monthlyRate)
                .totalRentalFee(totalRentalFee)
                .depositAmount(depositAmount)
                .totalExtraFees(totalExtraFees)
                .initialPaymentAmount(initialPayment)
                .breakdown(breakdown)
                .quotedAt(LocalDateTime.now())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public BigDecimal calculateExtensionFee(StorageUnit storageUnit, int extraMonths) {
        if (storageUnit == null || storageUnit.getUnitType() == null) {
            throw new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND);
        }
        UnitType unitType = storageUnit.getUnitType();
        if (unitType.getBasePricePerMonth() == null) {
            throw new AppException(ErrorCode.UNIT_TYPE_PRICE_NOT_CONFIGURED);
        }
        BigDecimal monthlyRate = unitType.getBasePricePerMonth().setScale(0, RoundingMode.HALF_UP);
        return monthlyRate.multiply(BigDecimal.valueOf(extraMonths)).setScale(0, RoundingMode.HALF_UP);
    }

    @Override
    @Transactional(readOnly = true)
    public BigDecimal calculateDepositAmount(
            UUID facilityId,
            BigDecimal totalRentalFee,
            BigDecimal defaultDeposit
    ) {
        if (facilityId == null) {
            return defaultDeposit;
        }

        var policyOpt = facilityPolicyRepository.findByFacility_Id(facilityId);
        if (policyOpt.isEmpty()) {
            return defaultDeposit;
        }

        FacilityPolicy policy = policyOpt.get();
        if (policy.getDepositPercentage() != null && policy.getDepositPercentage() >= 0) {
            BigDecimal percentage = BigDecimal.valueOf(policy.getDepositPercentage());
            return totalRentalFee.multiply(percentage)
                    .divide(ONE_HUNDRED, 0, RoundingMode.HALF_UP);
        }

        return defaultDeposit;
    }

    @Override
    @Transactional(readOnly = true)
    public BigDecimal calculateLateFee(
            UUID facilityId,
            long chargeableDays
    ) {
        if (chargeableDays <= 0) {
            return BigDecimal.ZERO.setScale(
                    2,
                    RoundingMode.UNNECESSARY
            );
        }

        BigDecimal dailyLateFee = facilityPolicyService
                .getOverdueConfig(facilityId)
                .dailyLateFee();

        if (dailyLateFee == null || dailyLateFee.signum() < 0) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        return dailyLateFee
                .multiply(BigDecimal.valueOf(chargeableDays))
                .setScale(2, RoundingMode.HALF_UP);
    }

    @Override
    @Transactional(readOnly = true)
    public BigDecimal calculateCancellationRefund(
            UUID facilityId,
            BigDecimal depositPaid,
            LocalDateTime scheduledStart,
            LocalDateTime cancelTime
    ) {
        if (depositPaid == null || depositPaid.signum() <= 0) {
            return BigDecimal.ZERO;
        }

        var policyOpt = facilityPolicyRepository.findByFacility_Id(facilityId);
        if (policyOpt.isEmpty()) {
            return depositPaid;
        }

        FacilityPolicy policy = policyOpt.get();
        long hoursBeforeStart = Duration.between(cancelTime, scheduledStart).toHours();

        if (hoursBeforeStart >= policy.getCancellationFullRefundHours()) {
            return depositPaid;
        }
        if (hoursBeforeStart >= policy.getCancellationPartialRefundHours()) {
            return depositPaid
                    .multiply(BigDecimal.valueOf(policy.getCancellationPartialRefundPercent()))
                    .divide(ONE_HUNDRED, 0, RoundingMode.HALF_UP);
        }
        return BigDecimal.ZERO;
    }
}
