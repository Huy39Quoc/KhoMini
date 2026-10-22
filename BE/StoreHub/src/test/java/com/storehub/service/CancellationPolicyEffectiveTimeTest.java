package com.storehub.service;

import com.storehub.dto.request.FacilityPolicyUpdateRequest;
import com.storehub.entity.FacilityPolicy;
import com.storehub.mapper.FacilityPolicyMapper;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.service.impl.FacilityPolicyServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CancellationPolicyEffectiveTimeTest {
    @Mock FacilityPolicyRepository repository;
    @Mock FacilityRepository facilities;
    @Mock FacilityPolicyMapper mapper;
    @Mock ActivityLogService logs;
    @InjectMocks FacilityPolicyServiceImpl service;

    @Test
    void cancellationEditStartsANewEffectiveTime() {
        UUID id = UUID.randomUUID();
        LocalDateTime old = LocalDateTime.now().minusDays(1);
        FacilityPolicy policy = FacilityPolicy.builder().cancellationPolicyEffectiveAt(old).build();
        policy.setId(id);
        when(repository.findById(id)).thenReturn(Optional.of(policy));
        when(repository.save(policy)).thenReturn(policy);
        service.update(id, FacilityPolicyUpdateRequest.builder().cancellationPartialRefundPercent(25.0).build());
        assertTrue(policy.getCancellationPolicyEffectiveAt().isAfter(old));
    }

    @Test
    void unrelatedEditKeepsCancellationEffectiveTime() {
        UUID id = UUID.randomUUID();
        LocalDateTime old = LocalDateTime.now().minusDays(1);
        FacilityPolicy policy = FacilityPolicy.builder().cancellationPolicyEffectiveAt(old).build();
        policy.setId(id);
        when(repository.findById(id)).thenReturn(Optional.of(policy));
        when(repository.save(policy)).thenReturn(policy);
        service.update(id, FacilityPolicyUpdateRequest.builder().returnNoticeDays(2).build());
        assertEquals(old, policy.getCancellationPolicyEffectiveAt());
    }
}
