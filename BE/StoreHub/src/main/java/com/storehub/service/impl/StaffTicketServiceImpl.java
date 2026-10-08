package com.storehub.service.impl;

import com.storehub.common.PageResponse;
import com.storehub.dto.request.UpdateStaffTicketStatusRequest;
import com.storehub.dto.response.TicketResponse;
import com.storehub.entity.FacilityAccess;
import com.storehub.entity.SupportTicket;
import com.storehub.entity.User;
import com.storehub.enums.ActivityAction;
import com.storehub.enums.TicketStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.SupportTicketRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.StaffTicketService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class StaffTicketServiceImpl implements StaffTicketService {

    private final SupportTicketRepository ticketRepository;
    private final FacilityAccess facilityAccess;
    private final UserRepository userRepository;
    private final ActivityLogService activityLogService;

    @Override
    @Transactional(readOnly = true)
    public PageResponse<TicketResponse> getFacilityTickets(
            UUID facilityId,
            String staffEmail,
            Pageable pageable
    ) {
        facilityAccess.require(staffEmail, facilityId);

        return PageResponse.from(
                ticketRepository.findAllByFacilityId(facilityId, pageable)
                        .map(this::toResponse)
        );
    }

    @Override
    @Transactional
    public TicketResponse assignToMe(
            UUID facilityId,
            UUID ticketId,
            String staffEmail
    ) {
        User staff = facilityAccess.requireForUpdate(staffEmail, facilityId);
        SupportTicket ticket = requireTicket(ticketId, facilityId);

        if (ticket.getAssignedStaff() != null
                && staff.getId().equals(ticket.getAssignedStaff().getId())
                && ticket.getStatus() == TicketStatus.IN_PROGRESS) {
            return toResponse(ticket);
        }

        if (ticket.getStatus() != TicketStatus.OPEN
                || ticket.getAssignedStaff() != null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        ticket.setAssignedStaff(staff);
        ticket.setStatus(TicketStatus.IN_PROGRESS);

        SupportTicket updated = ticketRepository.save(ticket);

        activityLogService.record(
                ActivityAction.SUPPORT_TICKET_ASSIGN,
                "SUPPORT_TICKET",
                updated.getId(),
                "Staff accepted ticket " + updated.getTicketCode(),
                null,
                staff.getId()
        );

        return toResponse(updated);
    }

    @Override
    @Transactional
    public TicketResponse assignToStaff(
            UUID facilityId,
            UUID ticketId,
            UUID staffId,
            String managerEmail
    ) {
        User manager = facilityAccess.require(managerEmail, facilityId);
        User staff = userRepository.findByIdForUpdate(staffId)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        if (staff.getRole() == null
                || !"STAFF".equals(staff.getRole().getName())
                || staff.getFacility() == null
                || !facilityId.equals(staff.getFacility().getId())) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        SupportTicket ticket = requireTicket(ticketId, facilityId);

        if (ticket.getStatus() == TicketStatus.RESOLVED
                || ticket.getStatus() == TicketStatus.CLOSED) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        ticket.setAssignedStaff(staff);
        ticket.setStatus(TicketStatus.IN_PROGRESS);

        SupportTicket updated = ticketRepository.save(ticket);

        activityLogService.record(
                ActivityAction.SUPPORT_TICKET_ASSIGN,
                "SUPPORT_TICKET",
                updated.getId(),
                "Manager assigned ticket " + updated.getTicketCode()
                        + " to " + staff.getFullName(),
                null,
                staff.getId()
        );

        return toResponse(updated);
    }

    @Override
    @Transactional
    public TicketResponse updateStatus(
            UUID facilityId,
            UUID ticketId,
            String staffEmail,
            UpdateStaffTicketStatusRequest request
    ) {
        User staff = facilityAccess.require(staffEmail, facilityId);
        SupportTicket ticket = requireTicket(ticketId, facilityId);

        if (ticket.getAssignedStaff() == null
                || !staff.getId().equals(ticket.getAssignedStaff().getId())) {
            throw new AppException(ErrorCode.FORBIDDEN);
        }

        TicketStatus oldStatus = ticket.getStatus();
        TicketStatus newStatus = request.getStatus();

        validateStatusTransition(oldStatus, newStatus);

        boolean needsResolution = newStatus == TicketStatus.RESOLVED
                || newStatus == TicketStatus.CLOSED;

        if (needsResolution
                && !StringUtils.hasText(request.getResolutionNote())
                && !StringUtils.hasText(ticket.getResolutionNote())) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        ticket.setStatus(newStatus);

        if (StringUtils.hasText(request.getResolutionNote())) {
            ticket.setResolutionNote(request.getResolutionNote().trim());
        }

        SupportTicket updated = ticketRepository.save(ticket);

        ActivityAction action = switch (updated.getStatus()) {
            case RESOLVED -> ActivityAction.SUPPORT_TICKET_RESOLVE;
            case CLOSED -> ActivityAction.SUPPORT_TICKET_CLOSE;
            default -> ActivityAction.SUPPORT_TICKET_UPDATE;
        };

        activityLogService.record(
                action,
                "SUPPORT_TICKET",
                updated.getId(),
                "Updated ticket " + updated.getTicketCode()
                        + " from " + oldStatus
                        + " to " + updated.getStatus(),
                oldStatus,
                updated.getStatus()
        );

        return toResponse(updated);
    }

    private SupportTicket requireTicket(UUID ticketId, UUID facilityId) {
        return ticketRepository.findByIdAndFacilityIdForUpdate(ticketId, facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.TICKET_NOT_FOUND));
    }

    private void validateStatusTransition(
            TicketStatus currentStatus,
            TicketStatus newStatus
    ) {
        if (currentStatus == newStatus) {
            return;
        }

        boolean validTransition =
                (currentStatus == TicketStatus.IN_PROGRESS
                        && newStatus == TicketStatus.RESOLVED)
                        || (currentStatus == TicketStatus.RESOLVED
                        && newStatus == TicketStatus.CLOSED);

        if (!validTransition) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
    }

    private TicketResponse toResponse(SupportTicket ticket) {
        return TicketResponse.builder()
                .id(ticket.getId())
                .ticketCode(ticket.getTicketCode())
                .bookingId(ticket.getBooking() != null ? ticket.getBooking().getId() : null)
                .bookingCode(ticket.getBooking() != null ? ticket.getBooking().getBookingCode() : null)
                .category(ticket.getCategory())
                .title(ticket.getTitle())
                .description(ticket.getDescription())
                .status(ticket.getStatus())
                .priority(ticket.getPriority())
                .assignedStaffId(ticket.getAssignedStaff() != null
                        ? ticket.getAssignedStaff().getId()
                        : null)
                .assignedStaffName(ticket.getAssignedStaff() != null
                        ? ticket.getAssignedStaff().getFullName()
                        : null)
                .resolutionNote(ticket.getResolutionNote())
                .customerName(ticket.getCustomer() != null
                        ? ticket.getCustomer().getFullName()
                        : null)
                .customerEmail(ticket.getCustomer() != null
                        ? ticket.getCustomer().getEmail()
                        : null)
                .customerPhone(ticket.getCustomer() != null
                        ? ticket.getCustomer().getPhone()
                        : null)
                .unitCode(ticket.getBooking() != null
                        && ticket.getBooking().getStorageUnit() != null
                        ? ticket.getBooking().getStorageUnit().getUnitCode()
                        : null)
                .createdAt(ticket.getCreatedAt())
                .build();
    }
}
