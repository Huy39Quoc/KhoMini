package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
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
        User staff = facilityAccess.require(staffEmail, facilityId);
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

        if (request.getStatus() == TicketStatus.OPEN) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        boolean needsResolution = request.getStatus() == TicketStatus.RESOLVED
                || request.getStatus() == TicketStatus.CLOSED;

        if (needsResolution
                && !StringUtils.hasText(request.getResolutionNote())
                && !StringUtils.hasText(ticket.getResolutionNote())) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        TicketStatus oldStatus = ticket.getStatus();

        ticket.setStatus(request.getStatus());

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
        return ticketRepository.findByIdAndFacilityId(ticketId, facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.TICKET_NOT_FOUND));
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
                .createdAt(ticket.getCreatedAt())
                .build();
    }
}