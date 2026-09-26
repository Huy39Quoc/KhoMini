package com.storehub.dto.request;

import com.storehub.enums.TicketStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class UpdateStaffTicketStatusRequest {

    @NotNull(message = "Ticket status is required")
    private TicketStatus status;

    @Size(max = 2000, message = "Resolution note must not exceed 2000 characters")
    private String resolutionNote;
}