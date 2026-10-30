package com.storehub.service.impl;

import com.storehub.common.PageResponse;
import com.storehub.dto.response.NotificationResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.Notification;
import com.storehub.entity.User;
import com.storehub.enums.NotificationType;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.NotificationRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationServiceImpl implements NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final com.storehub.repository.FacilityRepository facilityRepository;

    @Override
    @Transactional(readOnly = true)
    public PageResponse<NotificationResponse> getMyNotifications(String userEmail, Boolean unreadOnly, Pageable pageable) {
        User user = resolveUser(userEmail);
        Page<Notification> page;
        if (Boolean.TRUE.equals(unreadOnly)) {
            page = notificationRepository.findByRecipient_IdAndIsReadOrderByCreatedAtDesc(user.getId(), false, pageable);
        } else {
            page = notificationRepository.findByRecipient_IdOrderByCreatedAtDesc(user.getId(), pageable);
        }
        return PageResponse.from(page.map(this::toResponse));
    }

    @Override
    @Transactional(readOnly = true)
    public long getUnreadCount(String userEmail) {
        User user = resolveUser(userEmail);
        return notificationRepository.countByRecipient_IdAndIsReadFalse(user.getId());
    }

    @Override
    @Transactional
    public void markAsRead(UUID id, String userEmail) {
        User user = resolveUser(userEmail);
        Notification notification = notificationRepository.findByIdAndRecipient_Id(id, user.getId())
                .orElseThrow(() -> new AppException(ErrorCode.INVALID_REQUEST));
        if (!Boolean.TRUE.equals(notification.getIsRead())) {
            notification.setIsRead(true);
            notification.setReadAt(LocalDateTime.now());
            notificationRepository.save(notification);
        }
    }

    @Override
    @Transactional
    public void markAllAsRead(String userEmail) {
        User user = resolveUser(userEmail);
        notificationRepository.markAllAsRead(user.getId(), LocalDateTime.now());
    }

    @Override
    @Transactional
    public void notifyUser(User recipient, String title, String content, NotificationType type,
                           UUID referenceId, String referenceType, Facility facility) {
        if (recipient == null) {
            return;
        }
        try {
            Notification notification = Notification.builder()
                    .recipient(recipient)
                    .title(title)
                    .content(content)
                    .type(type)
                    .referenceId(referenceId)
                    .referenceType(referenceType)
                    .facility(facility)
                    .isRead(false)
                    .build();
            notificationRepository.save(notification);
            log.info("Dispatched notification [{}] to user {} (email: {})", type, recipient.getId(), recipient.getEmail());
        } catch (Exception e) {
            log.error("Failed to create notification for user {}: {}", recipient.getEmail(), e.getMessage(), e);
        }
    }

    @Override
    @Transactional
    public void notifyFacilityManager(Facility facility, String title, String content, NotificationType type,
                                      UUID referenceId, String referenceType) {
        if (facility == null) {
            return;
        }
        Set<UUID> seenIds = new HashSet<>();
        List<User> recipients = new ArrayList<>();

        Facility freshFacility = facilityRepository.findById(facility.getId()).orElse(facility);
        if (freshFacility.getManager() != null && Boolean.TRUE.equals(freshFacility.getManager().getIsActive())) {
            recipients.add(freshFacility.getManager());
            seenIds.add(freshFacility.getManager().getId());
        }

        List<User> assignedManagers = userRepository.findByFacility_IdAndRole_NameAndIsActiveTrue(facility.getId(), "FACILITY_MANAGER");
        for (User mgr : assignedManagers) {
            if (seenIds.add(mgr.getId())) {
                recipients.add(mgr);
            }
        }

        if (recipients.isEmpty()) {
            List<User> allManagers = userRepository.findByRole_NameAndIsActiveTrue("FACILITY_MANAGER");
            for (User mgr : allManagers) {
                if (mgr.getFacility() == null || mgr.getFacility().getId().equals(facility.getId())) {
                    if (seenIds.add(mgr.getId())) {
                        recipients.add(mgr);
                    }
                }
            }
        }

        for (User manager : recipients) {
            notifyUser(manager, title, content, type, referenceId, referenceType, facility);
        }
    }

    @Override
    @Transactional
    public void notifyFacilityStaff(Facility facility, String title, String content, NotificationType type,
                                    UUID referenceId, String referenceType) {
        if (facility == null) {
            return;
        }
        List<User> staffList = userRepository.findByFacility_IdAndRole_NameAndIsActiveTrue(facility.getId(), "STAFF");
        for (User staff : staffList) {
            notifyUser(staff, title, content, type, referenceId, referenceType, facility);
        }
    }

    @Override
    @Transactional
    public void notifyFacilityManagerAndStaff(Facility facility, String title, String content, NotificationType type,
                                             UUID referenceId, String referenceType) {
        if (facility == null) {
            return;
        }
        Set<UUID> seenIds = new HashSet<>();
        List<User> recipients = new ArrayList<>();

        Facility freshFacility = facilityRepository.findById(facility.getId()).orElse(facility);
        if (freshFacility.getManager() != null && Boolean.TRUE.equals(freshFacility.getManager().getIsActive())) {
            recipients.add(freshFacility.getManager());
            seenIds.add(freshFacility.getManager().getId());
        }

        List<User> managers = userRepository.findByFacility_IdAndRole_NameAndIsActiveTrue(facility.getId(), "FACILITY_MANAGER");
        for (User mgr : managers) {
            if (seenIds.add(mgr.getId())) {
                recipients.add(mgr);
            }
        }

        List<User> staffList = userRepository.findByFacility_IdAndRole_NameAndIsActiveTrue(facility.getId(), "STAFF");
        for (User staff : staffList) {
            if (seenIds.add(staff.getId())) {
                recipients.add(staff);
            }
        }

        for (User user : recipients) {
            notifyUser(user, title, content, type, referenceId, referenceType, facility);
        }
    }

    @Override
    @Transactional
    public void notifyRole(String roleName, String title, String content, NotificationType type,
                           UUID referenceId, String referenceType) {
        if (roleName == null || roleName.isBlank()) {
            return;
        }
        List<User> users = userRepository.findByRole_NameAndIsActiveTrue(roleName.trim());
        for (User u : users) {
            notifyUser(u, title, content, type, referenceId, referenceType, u.getFacility());
        }
    }

    private User resolveUser(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
    }

    private NotificationResponse toResponse(Notification notification) {
        return NotificationResponse.builder()
                .id(notification.getId())
                .title(notification.getTitle())
                .content(notification.getContent())
                .type(notification.getType())
                .referenceId(notification.getReferenceId())
                .referenceType(notification.getReferenceType())
                .facilityId(notification.getFacility() != null ? notification.getFacility().getId() : null)
                .facilityName(notification.getFacility() != null ? notification.getFacility().getName() : null)
                .isRead(notification.getIsRead())
                .readAt(notification.getReadAt())
                .createdAt(notification.getCreatedAt())
                .build();
    }
}
