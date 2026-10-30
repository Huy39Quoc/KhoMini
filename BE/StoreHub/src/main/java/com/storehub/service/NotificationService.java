package com.storehub.service;

import com.storehub.common.PageResponse;
import com.storehub.dto.response.NotificationResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.User;
import com.storehub.enums.NotificationType;
import org.springframework.data.domain.Pageable;

import java.util.UUID;

public interface NotificationService {

    PageResponse<NotificationResponse> getMyNotifications(String userEmail, Boolean unreadOnly, Pageable pageable);

    long getUnreadCount(String userEmail);

    void markAsRead(UUID id, String userEmail);

    void markAllAsRead(String userEmail);

    void notifyUser(User recipient, String title, String content, NotificationType type,
                    UUID referenceId, String referenceType, Facility facility);

    void notifyFacilityManager(Facility facility, String title, String content, NotificationType type,
                               UUID referenceId, String referenceType);

    void notifyFacilityStaff(Facility facility, String title, String content, NotificationType type,
                             UUID referenceId, String referenceType);

    void notifyFacilityManagerAndStaff(Facility facility, String title, String content, NotificationType type,
                                       UUID referenceId, String referenceType);

    void notifyRole(String roleName, String title, String content, NotificationType type,
                    UUID referenceId, String referenceType);
}
