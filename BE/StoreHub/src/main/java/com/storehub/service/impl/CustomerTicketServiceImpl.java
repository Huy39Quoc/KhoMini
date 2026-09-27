package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.CreateTicketRequest;
import com.storehub.dto.response.TicketResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.SupportTicket;
import com.storehub.entity.User;
import com.storehub.enums.ActivityAction;
import com.storehub.enums.TicketStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.SupportTicketRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.CustomerTicketService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CustomerTicketServiceImpl implements CustomerTicketService {

    private final SupportTicketRepository ticketRepository;
    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final ActivityLogService activityLogService;

    @Override
    @Transactional
    public TicketResponse createTicket(String customerEmail, CreateTicketRequest request) {
        User customer = resolveCustomer(customerEmail);
        Booking booking = null;

        if (request.getBookingId() != null) {
            booking = bookingRepository.findByIdAndCustomerId(request.getBookingId(), customer.getId())
                    .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));
        }

        String ticketCode = "TK-" + System.currentTimeMillis();

        SupportTicket ticket = SupportTicket.builder()
                .ticketCode(ticketCode)
                .customer(customer)
                .booking(booking)
                .category(request.getCategory())
                .title(request.getTitle())
                .description(request.getDescription())
                .status(TicketStatus.OPEN)
                .priority("MEDIUM")
                .build();

        SupportTicket savedTicket = ticketRepository.save(ticket);

        activityLogService.record(customer.getId(), ActivityAction.SUPPORT_TICKET_CREATE, "SUPPORT_TICKET", savedTicket.getId(),
                "Created support ticket: " + savedTicket.getTicketCode() + " - " + savedTicket.getTitle(), null, savedTicket.getStatus());

        return mapToResponse(savedTicket);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<TicketResponse> getMyTickets(String customerEmail, Pageable pageable) {
        User customer = resolveCustomer(customerEmail);
        Page<SupportTicket> ticketPage = ticketRepository.findAllByCustomerId(customer.getId(), pageable);

        List<TicketResponse> responses = ticketPage.getContent().stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());

        return PageResponse.<TicketResponse>builder()
                .page(ticketPage.getNumber())
                .size(ticketPage.getSize())
                .totalElements(ticketPage.getTotalElements())
                .totalPages(ticketPage.getTotalPages())
                .content(responses)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public TicketResponse getTicketDetail(UUID ticketId, String customerEmail) {
        User customer = resolveCustomer(customerEmail);
        SupportTicket ticket = ticketRepository.findByIdAndCustomerId(ticketId, customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.TICKET_NOT_FOUND));
        return mapToResponse(ticket);
    }

    private User resolveCustomer(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
    }

    private TicketResponse mapToResponse(SupportTicket t) {
        return TicketResponse.builder()
                .id(t.getId())
                .ticketCode(t.getTicketCode())
                .bookingId(t.getBooking() != null ? t.getBooking().getId() : null)
                .bookingCode(t.getBooking() != null ? t.getBooking().getBookingCode() : null)
                .category(t.getCategory())
                .title(t.getTitle())
                .description(t.getDescription())
                .status(t.getStatus())
                .priority(t.getPriority())
                .assignedStaffId(t.getAssignedStaff() != null ? t.getAssignedStaff().getId() : null)
                .assignedStaffName(t.getAssignedStaff() != null ? t.getAssignedStaff().getFullName() : null)
                .resolutionNote(t.getResolutionNote())
                .createdAt(t.getCreatedAt())
                .build();
    }
}