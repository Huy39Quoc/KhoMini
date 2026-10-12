package com.storehub.service.impl;

import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.FeeItemResponse;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.FacilityPolicy;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.UnitType;
import com.storehub.enums.FacilityStatus;
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

        if (facility != null && facility.getStatus() != FacilityStatus.ACTIVE) {
            throw new AppException(ErrorCode.FACILITY_NOT_ACTIVE);
        }

        if (unitType.getBasePricePerMonth() == null) {
            throw new AppException(ErrorCode.UNIT_TYPE_PRICE_NOT_CONFIGURED);
        }

        int months = request.getRentalMonths();
        LocalDate startDate = request.getStartDate();
        LocalDate endDate = startDate.plusMonths(months);

        BigDecimal monthlyRate = unitType.getBasePricePerMonth().setScale(0, RoundingMode.HALF_UP);
        BigDecimal grossRentalFee = monthlyRate.multiply(BigDecimal.valueOf(months)).setScale(0, RoundingMode.HALF_UP);

        // Giảm giá thuê dài hạn (cấu hình trong FacilityPolicy)
        UUID policyFacilityId = facility != null ? facility.getId() : null;
        BigDecimal discountAmount = BigDecimal.ZERO;
        double discountPercent = 0;
        if (policyFacilityId != null) {
            var policyForDiscount = facilityPolicyRepository.findByFacility_Id(policyFacilityId);
            if (policyForDiscount.isPresent()) {
                FacilityPolicy p = policyForDiscount.get();
                int minMonths = p.getLongTermDiscountMinMonths() == null ? 0 : p.getLongTermDiscountMinMonths();
                discountPercent = p.getLongTermDiscountPercent() == null ? 0 : p.getLongTermDiscountPercent();
                if (minMonths > 0 && months >= minMonths && discountPercent > 0) {
                    discountAmount = grossRentalFee.multiply(BigDecimal.valueOf(discountPercent))
                            .divide(ONE_HUNDRED, 0, RoundingMode.HALF_UP);
                } else {
                    discountPercent = 0;
                }
            }
        }
        BigDecimal totalRentalFee = grossRentalFee.subtract(discountAmount);

        BigDecimal defaultDeposit = (unitType.getDepositAmount() != null)
                ? unitType.getDepositAmount().setScale(0, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
        UUID facilityIdForDeposit = facility != null ? facility.getId() : null;
        BigDecimal depositAmount = calculateDepositAmount(facilityIdForDeposit, totalRentalFee, defaultDeposit);

        BigDecimal managementFeePerMonth = resolveManagementFeePerMonth(facility != null ? facility.getId() : null);
        BigDecimal totalManagementFee = managementFeePerMonth.multiply(BigDecimal.valueOf(months)).setScale(0, RoundingMode.HALF_UP);
        BigDecimal totalExtraFees = totalManagementFee;

        BigDecimal initialPayment = totalRentalFee.add(depositAmount).add(totalExtraFees);

        List<FeeItemResponse> breakdown = new ArrayList<>();
        breakdown.add(FeeItemResponse.builder()
                .feeType(RentalFeeType.RENTAL_FEE)
                .name("Tiền thuê kho")
                .unitPrice(monthlyRate)
                .quantity(months)
                .totalAmount(grossRentalFee)
                .note("Đơn giá: " + CURRENCY_FORMAT.format(monthlyRate) + " VNĐ / tháng")
                .build());

        if (discountAmount.signum() > 0) {
            breakdown.add(FeeItemResponse.builder()
                    .feeType(RentalFeeType.DISCOUNT)
                    .name("Giảm giá thuê dài hạn")
                    .unitPrice(discountAmount.negate())
                    .quantity(1)
                    .totalAmount(discountAmount.negate())
                    .note("Giảm " + (discountPercent == Math.floor(discountPercent) ? String.valueOf((long) discountPercent) : String.valueOf(discountPercent))
                            + "% khi thuê từ " + months + " tháng")
                    .build());
        }

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
                .unitPrice(managementFeePerMonth)
                .quantity(months)
                .totalAmount(totalManagementFee)
                .note(managementFeePerMonth.signum() == 0
                        ? "Miễn phí quản lý"
                        : "Đơn giá: " + CURRENCY_FORMAT.format(managementFeePerMonth) + " VNĐ / tháng")
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
        BigDecimal rent = monthlyRate.multiply(BigDecimal.valueOf(extraMonths)).setScale(0, RoundingMode.HALF_UP);
        // Gia hạn cũng phải trả phí quản lý của các tháng gia hạn thêm
        UUID facilityId = storageUnit.getFacility() != null ? storageUnit.getFacility().getId() : null;
        return rent.add(calculateManagementFee(facilityId, extraMonths));
    }

    @Override
    @Transactional(readOnly = true)
    public BigDecimal calculateManagementFee(UUID facilityId, int months) {
        return resolveManagementFeePerMonth(facilityId)
                .multiply(BigDecimal.valueOf(months))
                .setScale(0, RoundingMode.HALF_UP);
    }

    private BigDecimal resolveManagementFeePerMonth(UUID facilityId) {
        if (facilityId != null) {
            var policy = facilityPolicyRepository.findByFacility_Id(facilityId);
            if (policy.isPresent() && policy.get().getManagementFeePerMonth() != null) {
                return policy.get().getManagementFeePerMonth().setScale(0, RoundingMode.HALF_UP);
            }
        }
        return STANDARD_MANAGEMENT_FEE;
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
