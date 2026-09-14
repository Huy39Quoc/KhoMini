package com.storehub.service;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.CreateTicketRequest;
import com.storehub.dto.response.TicketResponse;
import com.storehub.entity.User;
import org.springframework.data.domain.Pageable;

public interface CustomerTicketService {

    TicketResponse createTicket(User customer, CreateTicketRequest request);

    PageResponse<TicketResponse> getMyTickets(User customer, Pageable pageable);

    TicketResponse getTicketDetail(Long ticketId, User customer);
}