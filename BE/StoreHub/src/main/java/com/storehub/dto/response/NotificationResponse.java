package com.storehub.dto.response;

import com.storehub.enums.NotificationType;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationResponse {
    private UUID id;
    private String title;
    private String content;
    private NotificationType type;
    private UUID referenceId;
    private String referenceType;
    private UUID facilityId;
    private String facilityName;
    private Boolean isRead;
    private LocalDateTime readAt;
    private LocalDateTime createdAt;
}
