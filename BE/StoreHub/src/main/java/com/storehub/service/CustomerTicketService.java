package com.storehub.service;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.CreateTicketRequest;
import com.storehub.dto.response.TicketResponse;
import org.springframework.data.domain.Pageable;

import java.util.UUID;

public interface CustomerTicketService {

    TicketResponse createTicket(String customerEmail, CreateTicketRequest request);

    PageResponse<TicketResponse> getMyTickets(String customerEmail, Pageable pageable);

    TicketResponse getTicketDetail(UUID ticketId, String customerEmail);
}