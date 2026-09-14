package com.storehub.dto.response;

import com.storehub.enums.TicketCategory;
import com.storehub.enums.TicketStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TicketResponse {
    private UUID id;
    private String ticketCode;
    private Long bookingId;
    private String bookingCode;
    private TicketCategory category;
    private String title;
    private String description;
    private TicketStatus status;
    private String priority;
    private String resolutionNote;
    private LocalDateTime createdAt;
}