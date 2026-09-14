package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.CreateTicketRequest;
import com.storehub.dto.response.TicketResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.SupportTicket;
import com.storehub.entity.User;
import com.storehub.enums.TicketStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.SupportTicketRepository;
import com.storehub.service.CustomerTicketService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CustomerTicketServiceImpl implements CustomerTicketService {

    private final SupportTicketRepository ticketRepository;
    private final BookingRepository bookingRepository;

    @Override
    @Transactional
    public TicketResponse createTicket(User customer, CreateTicketRequest request) {
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
        return mapToResponse(savedTicket);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<TicketResponse> getMyTickets(User customer, Pageable pageable) {
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
    public TicketResponse getTicketDetail(Long ticketId, User customer) {
        SupportTicket ticket = ticketRepository.findByIdAndCustomerId(ticketId, customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        return mapToResponse(ticket);
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
                .resolutionNote(t.getResolutionNote())
                .createdAt(t.getCreatedAt())
                .build();
    }
}