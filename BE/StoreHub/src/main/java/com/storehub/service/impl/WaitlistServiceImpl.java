package com.storehub.service.impl;

import com.storehub.entity.Facility;
import com.storehub.entity.UnitType;
import com.storehub.entity.User;
import com.storehub.entity.Waitlist;
import com.storehub.enums.WaitlistStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.enums.FacilityStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UserRepository;
import com.storehub.repository.WaitlistRepository;
import com.storehub.service.EmailService;
import com.storehub.service.WaitlistService;
import com.storehub.dto.response.WaitlistResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class WaitlistServiceImpl implements WaitlistService {

    private final WaitlistRepository waitlistRepository;
    private final UserRepository userRepository;
    private final FacilityRepository facilityRepository;
    private final UnitTypeRepository unitTypeRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final EmailService emailService;

    @Override
    @Transactional
    public void joinWaitlist(String customerEmail, UUID facilityId, UUID unitTypeId) {
        User customer = userRepository.findByEmailForUpdate(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        if (customer.getRole() == null || !"CUSTOMER".equals(customer.getRole().getName())) {
            throw new AppException(ErrorCode.FORBIDDEN);
        }

        boolean alreadyWaiting = waitlistRepository
                .existsByCustomer_IdAndFacility_IdAndUnitType_IdAndStatusIn(
                        customer.getId(), facilityId, unitTypeId,
                        List.of(WaitlistStatus.WAITING, WaitlistStatus.NOTIFIED));
        if (alreadyWaiting) {
            log.info("Customer {} already in waitlist for facility {} unitType {}",
                    customerEmail, facilityId, unitTypeId);
            return;
        }

        Facility facility = facilityRepository.findById(facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));
        if (facility.getStatus() != FacilityStatus.ACTIVE) {
            throw new AppException(ErrorCode.FACILITY_NOT_ACTIVE);
        }

        UnitType unitType = unitTypeRepository.findById(unitTypeId)
                .orElseThrow(() -> new AppException(ErrorCode.UNIT_TYPE_NOT_FOUND));

        if (storageUnitRepository.existsByFacility_IdAndUnitType_IdAndStatus(
                facilityId, unitTypeId, UnitStatus.AVAILABLE)) {
            throw new AppException(ErrorCode.WAITLIST_UNITS_AVAILABLE);
        }

        Waitlist waitlist = Waitlist.builder()
                .customer(customer)
                .facility(facility)
                .unitType(unitType)
                .status(WaitlistStatus.WAITING)
                .build();

        waitlistRepository.save(waitlist);
        log.info("Customer {} added to waitlist for facility {} unitType {}",
                customerEmail, facilityId, unitTypeId);
    }

    @Override
    @Transactional
    public void notifyNextInWaitlist(UUID facilityId, UUID unitTypeId) {
        if (!storageUnitRepository.existsByFacility_IdAndUnitType_IdAndStatus(
                facilityId, unitTypeId, UnitStatus.AVAILABLE)) return;

        List<Waitlist> waitingList = waitlistRepository.findOpenForUpdate(
                facilityId, unitTypeId, List.of(WaitlistStatus.WAITING, WaitlistStatus.NOTIFIED));

        Instant now = Instant.now();
        // Mỗi loại kho chỉ có một thông báo còn hạn; thông báo hết hạn nhường lượt.
        for (Waitlist entry : waitingList) {
            if (entry.getStatus() == WaitlistStatus.NOTIFIED) {
                if (entry.getOfferExpiresAt() == null || entry.getOfferExpiresAt().isAfter(now)) return;
                entry.setStatus(WaitlistStatus.EXPIRED);
                waitlistRepository.save(entry);
            }
        }

        Waitlist first = waitingList.stream()
                .filter(w -> w.getStatus() == WaitlistStatus.WAITING).findFirst().orElse(null);
        if (first == null) {
            log.info("No one waiting for facility {} unitType {}", facilityId, unitTypeId);
            return;
        }

        User customer = first.getCustomer();

        try {
            emailService.sendWaitlistNotificationEmail(
                    customer.getEmail(),
                    customer.getFullName(),
                    first.getFacility().getName(),
                    first.getUnitType().getTypeName()
            );
            first.setStatus(WaitlistStatus.NOTIFIED);
            first.setNotifiedAt(now);
            first.setOfferExpiresAt(now.plus(24, ChronoUnit.HOURS));
            waitlistRepository.save(first);
            log.info("Waitlist notification sent to {} for facility {} unitType {}",
                    customer.getEmail(), facilityId, unitTypeId);
        } catch (Exception e) {
            log.error("Failed to send waitlist notification email to {}: {}",
                    customer.getEmail(), e.getMessage());
        }
    }

    @Override
    @Transactional
    public void expireStaleNotifications() {
        Instant now = Instant.now();
        List<Waitlist> expired = waitlistRepository.findExpiredOffersForUpdate(
                WaitlistStatus.NOTIFIED, now);
        for (Waitlist entry : expired) {
            entry.setStatus(WaitlistStatus.EXPIRED);
            waitlistRepository.save(entry);
        }
        // Retry cả trường hợp email hỏng ở lần mở kho trước: người chờ vẫn WAITING.
        for (Object[] pair : waitlistRepository.findWaitingPairs(WaitlistStatus.WAITING)) {
            notifyNextInWaitlist((UUID) pair[0], (UUID) pair[1]);
        }
    }

    @Override
    @Transactional
    public void markFulfilled(UUID customerId, UUID facilityId, UUID unitTypeId) {
        waitlistRepository.markFulfilled(customerId, facilityId, unitTypeId,
                List.of(WaitlistStatus.WAITING, WaitlistStatus.NOTIFIED), WaitlistStatus.FULFILLED);
    }

    @Override
    @Transactional(readOnly = true)
    public List<WaitlistResponse> myWaitlist(String customerEmail) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        return waitlistRepository.findByCustomer_IdOrderByCreatedAtDesc(customer.getId())
                .stream().map(w -> new WaitlistResponse(w.getId(), w.getFacility().getId(),
                        w.getFacility().getName(), w.getUnitType().getId(),
                        w.getUnitType().getTypeName(), w.getStatus(),
                        w.getNotifiedAt(), w.getOfferExpiresAt())).toList();
    }

    @Override
    @Transactional
    public void leaveWaitlist(String customerEmail, UUID waitlistId) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        Waitlist entry = waitlistRepository.findOwnedForUpdate(waitlistId, customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.INVALID_REQUEST));
        if (entry.getStatus() != WaitlistStatus.WAITING
                && entry.getStatus() != WaitlistStatus.NOTIFIED) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        boolean offered = entry.getStatus() == WaitlistStatus.NOTIFIED;
        entry.setStatus(WaitlistStatus.CANCELLED);
        waitlistRepository.save(entry);
        if (offered) notifyNextInWaitlist(entry.getFacility().getId(), entry.getUnitType().getId());
    }
}
