package com.storehub.service;

import com.storehub.dto.response.NotificationResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.Notification;
import com.storehub.entity.User;
import com.storehub.enums.NotificationType;
import com.storehub.repository.NotificationRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.NotificationServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock
    private NotificationRepository notificationRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private com.storehub.repository.FacilityRepository facilityRepository;

    @InjectMocks
    private NotificationServiceImpl notificationService;

    private Facility facilityD1;
    private User managerD1;
    private User staff1D1;
    private User staff2D1;

    @BeforeEach
    void setUp() {
        facilityD1 = Facility.builder()
                .code("HCM-D1")
                .name("StoreHub Q1")
                .address("123 Le Loi, Q1")
                .build();
        facilityD1.setId(UUID.randomUUID());

        managerD1 = User.builder()
                .username("facility1")
                .email("facility1@gmail.com")
                .fullName("Facility Manager 1")
                .isActive(true)
                .facility(facilityD1)
                .build();
        managerD1.setId(UUID.randomUUID());
        facilityD1.setManager(managerD1);

        staff1D1 = User.builder()
                .username("staff1")
                .email("staff1@gmail.com")
                .fullName("Staff 1")
                .isActive(true)
                .facility(facilityD1)
                .build();
        staff1D1.setId(UUID.randomUUID());

        staff2D1 = User.builder()
                .username("staff2")
                .email("staff2@gmail.com")
                .fullName("Staff 2")
                .isActive(true)
                .facility(facilityD1)
                .build();
        staff2D1.setId(UUID.randomUUID());
    }

    @Test
    @DisplayName("notifyFacilityManager: Gửi thông báo đến đúng Quản lý của cơ sở đó")
    void testNotifyFacilityManager() {
        when(userRepository.findByFacility_IdAndRole_NameAndIsActiveTrue(facilityD1.getId(), "FACILITY_MANAGER"))
                .thenReturn(List.of(managerD1));

        UUID bookingId = UUID.randomUUID();
        notificationService.notifyFacilityManager(
                facilityD1,
                "Đơn đặt chỗ mới cần xác nhận",
                "Khách hàng vừa đặt chỗ",
                NotificationType.BOOKING_NEW,
                bookingId,
                "BOOKING"
        );

        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository, times(1)).save(captor.capture());

        Notification saved = captor.getValue();
        assertThat(saved.getRecipient().getEmail()).isEqualTo("facility1@gmail.com");
        assertThat(saved.getTitle()).isEqualTo("Đơn đặt chỗ mới cần xác nhận");
        assertThat(saved.getType()).isEqualTo(NotificationType.BOOKING_NEW);
        assertThat(saved.getReferenceId()).isEqualTo(bookingId);
        assertThat(saved.getReferenceType()).isEqualTo("BOOKING");
        assertThat(saved.getIsRead()).isFalse();
    }

    @Test
    @DisplayName("notifyFacilityStaff: Gửi thông báo đến tất cả nhân viên thuộc cơ sở liên quan")
    void testNotifyFacilityStaff() {
        when(userRepository.findByFacility_IdAndRole_NameAndIsActiveTrue(facilityD1.getId(), "STAFF"))
                .thenReturn(List.of(staff1D1, staff2D1));

        UUID ticketId = UUID.randomUUID();
        notificationService.notifyFacilityStaff(
                facilityD1,
                "Sự cố mới",
                "Có sự cố tại ngăn A-101",
                NotificationType.TICKET_NEW,
                ticketId,
                "SUPPORT_TICKET"
        );

        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository, times(2)).save(captor.capture());

        List<Notification> allSaved = captor.getAllValues();
        assertThat(allSaved).extracting(n -> n.getRecipient().getEmail())
                .containsExactlyInAnyOrder("staff1@gmail.com", "staff2@gmail.com");
    }

    @Test
    @DisplayName("notifyFacilityManagerAndStaff: Không gửi trùng lặp nếu người dùng trùng id")
    void testNotifyFacilityManagerAndStaffNoDuplicates() {
        when(userRepository.findByFacility_IdAndRole_NameAndIsActiveTrue(facilityD1.getId(), "FACILITY_MANAGER"))
                .thenReturn(List.of(managerD1));
        when(userRepository.findByFacility_IdAndRole_NameAndIsActiveTrue(facilityD1.getId(), "STAFF"))
                .thenReturn(List.of(staff1D1));

        notificationService.notifyFacilityManagerAndStaff(
                facilityD1,
                "Yêu cầu hỗ trợ mới",
                "Nội dung ticket",
                NotificationType.TICKET_NEW,
                UUID.randomUUID(),
                "SUPPORT_TICKET"
        );

        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository, times(2)).save(captor.capture());

        List<Notification> allSaved = captor.getAllValues();
        assertThat(allSaved).extracting(n -> n.getRecipient().getEmail())
                .containsExactlyInAnyOrder("facility1@gmail.com", "staff1@gmail.com");
    }

    @Test
    @DisplayName("markAsRead: Đánh dấu đã đọc và cập nhật thời gian readAt")
    void testMarkAsRead() {
        UUID notifId = UUID.randomUUID();
        Notification notif = Notification.builder()
                .recipient(managerD1)
                .title("Thông báo")
                .content("Nội dung")
                .type(NotificationType.BOOKING_NEW)
                .isRead(false)
                .build();
        notif.setId(notifId);

        when(userRepository.findByEmail("facility1@gmail.com")).thenReturn(Optional.of(managerD1));
        when(notificationRepository.findByIdAndRecipient_Id(notifId, managerD1.getId())).thenReturn(Optional.of(notif));

        notificationService.markAsRead(notifId, "facility1@gmail.com");

        assertThat(notif.getIsRead()).isTrue();
        assertThat(notif.getReadAt()).isNotNull();
        verify(notificationRepository).save(notif);
    }

    @Test
    @DisplayName("getUnreadCount: Lấy số lượng thông báo chưa đọc")
    void testGetUnreadCount() {
        when(userRepository.findByEmail("facility1@gmail.com")).thenReturn(Optional.of(managerD1));
        when(notificationRepository.countByRecipient_IdAndIsReadFalse(managerD1.getId())).thenReturn(5L);

        long count = notificationService.getUnreadCount("facility1@gmail.com");
        assertThat(count).isEqualTo(5L);
    }

    @Test
    @DisplayName("notifyRole: Gửi thông báo đến tất cả người dùng trong role")
    void testNotifyRole() {
        when(userRepository.findByRole_NameAndIsActiveTrue("BUSINESS_MANAGER"))
                .thenReturn(List.of(managerD1));

        notificationService.notifyRole(
                "BUSINESS_MANAGER",
                "Tiêu đề hệ thống",
                "Nội dung hệ thống",
                NotificationType.BOOKING_NEW,
                UUID.randomUUID(),
                "BOOKING"
        );

        verify(notificationRepository, times(1)).save(any(Notification.class));
    }
}
