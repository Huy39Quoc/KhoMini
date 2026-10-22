package com.storehub.dto.request;

import com.storehub.enums.TicketCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateTicketRequest {

    @NotNull(
            message = "Cần chọn đơn thuê để yêu cầu hỗ trợ được chuyển đúng cơ sở"
    )
    private UUID bookingId;

    @NotNull(message = "Vui lòng chọn loại sự cố")
    private TicketCategory category;

    @NotBlank(message = "Vui lòng nhập tiêu đề")
    @Size(
            max = 255,
            message = "Tiêu đề tối đa 255 ký tự"
    )
    private String title;

    @NotBlank(message = "Vui lòng nhập mô tả")
    private String description;

    private List<String> photos;
}