package com.storehub.dto.response;

import com.storehub.enums.ActivityAction;
import com.storehub.enums.ActivityLogStatus;
import com.storehub.enums.ActivityLogType;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@AllArgsConstructor
@Builder
public class ActivityLogResponse {
    private UUID id;
    private UUID userId;
    private String userName;
    private String userEmail;

    private ActivityLogType logType;
    private ActivityAction action;
    private boolean critical;
    private String emailAttempted;

    private String resourceType;
    private UUID resourceId;
    private String description;
    private String oldValue;
    private String newValue;

    private ActivityLogStatus status;
    private String ipAddress;
    private String userAgent;
    private LocalDateTime createdAt;
}