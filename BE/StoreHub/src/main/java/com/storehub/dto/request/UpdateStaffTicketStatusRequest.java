package com.storehub.dto.request;

import com.storehub.enums.TicketStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class UpdateStaffTicketStatusRequest {

    @NotNull(message = "Vui lòng chọn trạng thái yêu cầu")
    private TicketStatus status;

    @Size(max = 2000, message = "Ghi chú xử lý tối đa 2000 ký tự")
    private String resolutionNote;
}