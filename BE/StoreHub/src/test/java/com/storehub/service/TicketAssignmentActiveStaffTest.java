package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.exception.*;
import com.storehub.repository.SupportTicketRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.StaffTicketServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TicketAssignmentActiveStaffTest {
    @Mock SupportTicketRepository tickets;
    @Mock FacilityAccess access;
    @Mock UserRepository users;
    @Mock ActivityLogService log;
    @InjectMocks StaffTicketServiceImpl service;

    @Test
    void managerCannotAssignTicketToDeactivatedEmployee() {
        UUID facilityId = UUID.randomUUID(), staffId = UUID.randomUUID();
        Facility facility = new Facility();
        facility.setId(facilityId);
        User staff = User.builder().role(Role.builder().name("STAFF").build())
                .facility(facility).isActive(false).build();
        when(access.require("manager@test.com", facilityId)).thenReturn(new User());
        when(users.findByIdForUpdate(staffId)).thenReturn(Optional.of(staff));

        AppException error = assertThrows(AppException.class,
                () -> service.assignToStaff(facilityId, UUID.randomUUID(), staffId,
                        "manager@test.com"));

        assertEquals(ErrorCode.INVALID_REQUEST, error.getErrorCode());
        verifyNoInteractions(tickets);
    }
}
