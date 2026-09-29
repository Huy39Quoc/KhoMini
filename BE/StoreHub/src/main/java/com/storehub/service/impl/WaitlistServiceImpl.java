package com.storehub.service.impl;

import com.storehub.entity.Facility;
import com.storehub.entity.UnitType;
import com.storehub.entity.User;
import com.storehub.entity.Waitlist;
import com.storehub.enums.WaitlistStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.repository.UserRepository;
import com.storehub.repository.WaitlistRepository;
import com.storehub.service.EmailService;
import com.storehub.service.WaitlistService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class WaitlistServiceImpl implements WaitlistService {

    private final WaitlistRepository waitlistRepository;
    private final UserRepository userRepository;
    private final FacilityRepository facilityRepository;
    private final UnitTypeRepository unitTypeRepository;
    private final EmailService emailService;

    @Override
    @Transactional
    public void joinWaitlist(String customerEmail, UUID facilityId, UUID unitTypeId) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        boolean alreadyWaiting = waitlistRepository
                .existsByCustomer_IdAndFacility_IdAndUnitType_IdAndStatus(
                        customer.getId(), facilityId, unitTypeId, WaitlistStatus.WAITING);
        if (alreadyWaiting) {
            log.info("Customer {} already in waitlist for facility {} unitType {}",
                    customerEmail, facilityId, unitTypeId);
            return;
        }

        Facility facility = facilityRepository.findById(facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));

        UnitType unitType = unitTypeRepository.findById(unitTypeId)
                .orElseThrow(() -> new AppException(ErrorCode.UNIT_TYPE_NOT_FOUND));

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
        List<Waitlist> waitingList = waitlistRepository.findByFacilityAndUnitTypeAndStatus(
                facilityId, unitTypeId, WaitlistStatus.WAITING);

        if (waitingList.isEmpty()) {
            log.info("No one waiting for facility {} unitType {}", facilityId, unitTypeId);
            return;
        }

        Waitlist first = waitingList.get(0);
        User customer = first.getCustomer();

        first.setStatus(WaitlistStatus.NOTIFIED);
        waitlistRepository.save(first);

        try {
            emailService.sendWaitlistNotificationEmail(
                    customer.getEmail(),
                    customer.getFullName(),
                    first.getFacility().getName(),
                    first.getUnitType().getTypeName()
            );
            log.info("Waitlist notification sent to {} for facility {} unitType {}",
                    customer.getEmail(), facilityId, unitTypeId);
        } catch (Exception e) {
            log.error("Failed to send waitlist notification email to {}: {}",
                    customer.getEmail(), e.getMessage());
        }
    }
}
