package com.storehub.service.impl;

import com.storehub.common.PageResponse;
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
    private final com.storehub.service.CloudinaryService cloudinaryService;

    @Override
    @Transactional
    public TicketResponse createTicket(String customerEmail, CreateTicketRequest request) {
        User customer = resolveCustomer(customerEmail);
        if (request.getBookingId() == null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        Booking booking = bookingRepository.findByIdAndCustomerId(
                        request.getBookingId(), customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        String ticketCode = "TK-" + System.currentTimeMillis() + "-"
                + UUID.randomUUID().toString().substring(0, 4).toUpperCase();

        SupportTicket ticket = SupportTicket.builder()
                .ticketCode(ticketCode)
                .customer(customer)
                .booking(booking)
                .category(request.getCategory())
                .title(request.getTitle())
                .description(request.getDescription())
                .status(TicketStatus.OPEN)
                .priority("MEDIUM")
                .photos(request.getPhotos())
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

        return PageResponse.from(ticketPage.map(this::mapToResponse));
    }

    @Override
    @Transactional(readOnly = true)
    public TicketResponse getTicketDetail(UUID ticketId, String customerEmail) {
        User customer = resolveCustomer(customerEmail);
        SupportTicket ticket = ticketRepository.findByIdAndCustomerId(ticketId, customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.TICKET_NOT_FOUND));
        return mapToResponse(ticket);
    }

    @Override
    public List<String> uploadTicketPhotos(org.springframework.web.multipart.MultipartFile[] files) {
        if (files == null || files.length == 0) {
            return java.util.Collections.emptyList();
        }
        List<String> urls = new java.util.ArrayList<>();
        for (org.springframework.web.multipart.MultipartFile file : files) {
            if (file != null && !file.isEmpty()) {
                urls.add(cloudinaryService.uploadImage(file, "tickets"));
            }
        }
        return urls;
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
                .customerName(t.getCustomer() != null ? t.getCustomer().getFullName() : null)
                .customerEmail(t.getCustomer() != null ? t.getCustomer().getEmail() : null)
                .customerPhone(t.getCustomer() != null ? t.getCustomer().getPhone() : null)
                .unitCode(t.getBooking() != null && t.getBooking().getStorageUnit() != null
                        ? t.getBooking().getStorageUnit().getUnitCode()
                        : null)
                .photos(t.getPhotos())
                .createdAt(t.getCreatedAt())
                .build();
    }
}
