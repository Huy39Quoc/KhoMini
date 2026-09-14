package com.storehub.dto.request;

import com.storehub.enums.TicketCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateTicketRequest {

    private Long bookingId; // Không bắt buộc (có thể hỏi chung hoặc gắn vào 1 đơn kho cụ thể)

    @NotNull(message = "Ticket category cannot be null")
    private TicketCategory category;

    @NotBlank(message = "Title cannot be blank")
    @Size(max = 255, message = "Title cannot exceed 255 characters")
    private String title;

    @NotBlank(message = "Description cannot be blank")
    private String description;
}