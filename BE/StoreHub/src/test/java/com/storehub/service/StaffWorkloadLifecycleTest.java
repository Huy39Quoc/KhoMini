package com.storehub.service;

import com.storehub.dto.request.UserUpdateRequest;
import com.storehub.entity.*;
import com.storehub.enums.TicketStatus;
import com.storehub.exception.*;
import com.storehub.mapper.UserMapper;
import com.storehub.repository.*;
import com.storehub.service.impl.UserServiceImpl;
import com.storehub.service.impl.FacilityManagementServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.util.Optional;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StaffWorkloadLifecycleTest {
    @Mock UserRepository users;
    @Mock RoleRepository roles;
    @Mock UserMapper mapper;
    @Mock PasswordEncoder encoder;
    @Mock ActivityLogService logs;
    @Mock BookingRepository bookings;
    @Mock SupportTicketRepository tickets;
    @Mock FacilityRepository facilities;
    @Mock FacilityAccess access;
    UserServiceImpl service;
    StaffWorkloadService workload;
    User staff;
    UUID id;

    @BeforeEach
    void setup() {
        workload = new StaffWorkloadService(bookings, tickets);
        service = new UserServiceImpl(users, roles, mapper, encoder, logs, workload);
        id = UUID.randomUUID();
        staff = User.builder().role(Role.builder().name("STAFF").build()).isActive(true).build();
        staff.setId(id);
        when(users.findByIdForUpdate(id)).thenReturn(Optional.of(staff));
    }

    void allowSave() { when(users.save(staff)).thenReturn(staff); }
    void assertReleased() {
        verify(bookings).clearOpenCheckInAssignments(id);
        verify(bookings).clearOpenCheckOutAssignments(id);
    }

    @Test
    void disablingReleasesBothOpenHandoverAssignments() {
        allowSave();
        service.toggleActive(id);
        assertFalse(staff.getIsActive());
        assertReleased();
    }

    @Test
    void reactivationDoesNotRestoreOrClearAssignments() {
        staff.setIsActive(false);
        allowSave();
        service.toggleActive(id);
        assertTrue(staff.getIsActive());
        verifyNoInteractions(bookings, tickets);
    }

    @Test
    void openTicketBlocksDisablingBeforeAccountOrAssignmentsChange() {
        when(tickets.existsByAssignedStaff_IdAndStatusNot(id, TicketStatus.CLOSED)).thenReturn(true);
        AppException error = assertThrows(AppException.class, () -> service.toggleActive(id));
        assertEquals(ErrorCode.STAFF_HAS_UNCLOSED_TICKETS, error.getErrorCode());
        assertTrue(staff.getIsActive());
        verifyNoInteractions(bookings);
        verify(users, never()).save(any());
    }

    @Test
    void profileDeactivationAlsoReleasesAssignments() {
        allowSave();
        service.update(id, UserUpdateRequest.builder().isActive(false).build());
        assertReleased();
        verify(mapper).updateEntityFromRequest(any(), eq(staff));
    }

    @Test
    void roleChangeReleasesAssignments() {
        allowSave();
        UUID roleId = UUID.randomUUID();
        Role customer = Role.builder().name("CUSTOMER").build();
        when(roles.findById(roleId)).thenReturn(Optional.of(customer));
        service.update(id, UserUpdateRequest.builder().roleId(roleId).build());
        assertSame(customer, staff.getRole());
        assertReleased();
    }

    @Test
    void openTicketBlocksRoleChangeBeforeMutatingRole() {
        UUID roleId = UUID.randomUUID();
        when(roles.findById(roleId)).thenReturn(Optional.of(Role.builder().name("CUSTOMER").build()));
        when(tickets.existsByAssignedStaff_IdAndStatusNot(id, TicketStatus.CLOSED)).thenReturn(true);
        assertThrows(AppException.class, () -> service.update(id, UserUpdateRequest.builder().roleId(roleId).build()));
        assertEquals("STAFF", staff.getRole().getName());
        verifyNoInteractions(bookings, mapper);
    }

    @Test
    void sameRoleAndNormalProfileEditsKeepAssignments() {
        allowSave();
        UUID roleId = UUID.randomUUID();
        when(roles.findById(roleId)).thenReturn(Optional.of(staff.getRole()));
        service.update(id, UserUpdateRequest.builder().roleId(roleId).fullName("New Name").build());
        verifyNoInteractions(bookings, tickets);
    }

    FacilityManagementServiceImpl management() {
        return new FacilityManagementServiceImpl(access, facilities, null, null, bookings,
                users, null, null, logs, null, null, workload);
    }

    Facility facility() {
        Facility facility = new Facility();
        facility.setId(UUID.randomUUID());
        return facility;
    }

    @Test
    void adminTransferReleasesOldFacilityAppointments() {
        staff.setFacility(facility());
        Facility destination = facility();
        when(facilities.findById(destination.getId())).thenReturn(Optional.of(destination));
        management().assignPerson(destination.getId(), id, "STAFF", null);
        assertSame(destination, staff.getFacility());
        assertReleased();
    }

    @Test
    void openTicketBlocksTransferBeforeChangingFacility() {
        Facility original = facility(), destination = facility();
        staff.setFacility(original);
        when(facilities.findById(destination.getId())).thenReturn(Optional.of(destination));
        when(tickets.existsByAssignedStaff_IdAndStatusNot(id, TicketStatus.CLOSED)).thenReturn(true);
        assertThrows(AppException.class, () -> management().assignPerson(destination.getId(), id, "STAFF", null));
        assertSame(original, staff.getFacility());
        verifyNoInteractions(bookings);
    }

    @Test
    void unassignUsesTheSameCleanup() {
        Facility original = facility();
        staff.setFacility(original);
        management().unassignStaff(original.getId(), id, "manager@test.com");
        assertNull(staff.getFacility());
        assertReleased();
    }
}
