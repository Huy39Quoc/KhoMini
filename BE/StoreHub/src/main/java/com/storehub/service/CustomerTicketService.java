package com.storehub.service;

import com.storehub.common.PageResponse;
import com.storehub.dto.request.CreateTicketRequest;
import com.storehub.dto.response.TicketResponse;
import org.springframework.data.domain.Pageable;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

public interface CustomerTicketService {

    TicketResponse createTicket(String customerEmail, CreateTicketRequest request);

    PageResponse<TicketResponse> getMyTickets(String customerEmail, Pageable pageable);

    TicketResponse getTicketDetail(UUID ticketId, String customerEmail);

    List<String> uploadTicketPhotos(MultipartFile[] files);
}