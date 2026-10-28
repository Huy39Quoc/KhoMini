package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
public class HandoverIssueResolutionRequest {
    public enum Action { REPLACE_UNIT, RESCHEDULE, CANCEL_REFUND }
    @NotNull private Action action;
    private UUID replacementUnitId;
    private LocalDateTime scheduledCheckInTime;
    private Boolean customerAgreed;
    @NotBlank @Size(max = 2000) private String notes;
}
