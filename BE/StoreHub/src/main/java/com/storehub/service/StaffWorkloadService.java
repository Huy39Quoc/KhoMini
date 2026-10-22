package com.storehub.service;

import com.storehub.enums.TicketStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.SupportTicketRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class StaffWorkloadService {
    private final BookingRepository bookings;
    private final SupportTicketRepository tickets;

    // Caller holds the user row lock, shared with appointment/ticket assignment.
    @Transactional(propagation = Propagation.MANDATORY)
    public void releaseOpenAssignments(UUID userId) {
        if (tickets.existsByAssignedStaff_IdAndStatusNot(userId, TicketStatus.CLOSED)) {
            throw new AppException(ErrorCode.STAFF_HAS_UNCLOSED_TICKETS);
        }
        bookings.clearOpenCheckInAssignments(userId);
        bookings.clearOpenCheckOutAssignments(userId);
    }
}
