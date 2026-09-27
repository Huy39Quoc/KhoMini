package com.storehub.service;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.UpdateStaffTicketStatusRequest;
import com.storehub.dto.response.TicketResponse;
import org.springframework.data.domain.Pageable;

import java.util.UUID;

public interface StaffTicketService {

    PageResponse<TicketResponse> getFacilityTickets(
            UUID facilityId,
            String staffEmail,
            Pageable pageable
    );

    TicketResponse assignToMe(
            UUID facilityId,
            UUID ticketId,
            String staffEmail
    );

    TicketResponse updateStatus(
            UUID facilityId,
            UUID ticketId,
            String staffEmail,
            UpdateStaffTicketStatusRequest request
    );
}