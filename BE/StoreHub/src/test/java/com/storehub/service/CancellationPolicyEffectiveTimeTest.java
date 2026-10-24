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
    void policyResponsePublishesHashAndItTracksAllAgreementFields() throws Exception {
        var response = com.storehub.dto.response.FacilityPolicyResponse.builder()
                .termsVersion("v1").termsAndConditions("Terms").prohibitedItems("Items").build();
        String original = response.getTermsHash();
        var json = new com.fasterxml.jackson.databind.ObjectMapper();
        assertEquals(original, json.readTree(json.writeValueAsString(response)).path("termsHash").asText());
        response.setTermsVersion("v2");
        assertNotEquals(original, response.getTermsHash());
        response.setTermsVersion("v1");
        response.setProhibitedItems("Other items");
        assertNotEquals(original, response.getTermsHash());
        response.setProhibitedItems("Items");
        response.setTermsAndConditions("Other terms");
        assertNotEquals(original, response.getTermsHash());
    }

    @Test
    void legalContentCanBeUpdatedWithANewVersion() {
        UUID id = UUID.randomUUID();
        FacilityPolicy policy = FacilityPolicy.builder().termsVersion("v1").termsAndConditions("Original").build();
        policy.setId(id);
        when(repository.lockById(id)).thenReturn(Optional.of(policy));
        when(repository.save(policy)).thenReturn(policy);
        var request = FacilityPolicyUpdateRequest.builder().termsVersion("v2").termsAndConditions("Changed").build();
        assertDoesNotThrow(() -> service.update(id, request));
        verify(mapper).updateEntityFromRequest(request, policy);
        verify(repository).save(policy);
    }

    @Test
    void changedLegalContentRequiresANewVersion() {
        UUID id = UUID.randomUUID();
        FacilityPolicy policy = FacilityPolicy.builder().termsVersion("v1").termsAndConditions("Original").build();
        when(repository.lockById(id)).thenReturn(Optional.of(policy));
        var error = assertThrows(com.storehub.exception.AppException.class,
                () -> service.update(id, FacilityPolicyUpdateRequest.builder()
                        .termsVersion("v1").termsAndConditions("Changed").build()));
        assertEquals(com.storehub.exception.ErrorCode.TERMS_VERSION_REQUIRED, error.getErrorCode());
        verify(repository, never()).save(any());
    }

    @Test
    void changedProhibitedItemsAlsoRequiresANewVersion() {
        UUID id = UUID.randomUUID();
        FacilityPolicy policy = FacilityPolicy.builder().termsVersion("v1").prohibitedItems("Original").build();
        when(repository.lockById(id)).thenReturn(Optional.of(policy));
        assertThrows(com.storehub.exception.AppException.class,
                () -> service.update(id, FacilityPolicyUpdateRequest.builder().prohibitedItems("Changed").build()));
        verify(repository, never()).save(any());
    }

    @Test
    void cancellationEditStartsANewEffectiveTime() {
        UUID id = UUID.randomUUID();
        LocalDateTime old = LocalDateTime.now().minusDays(1);
        FacilityPolicy policy = FacilityPolicy.builder().cancellationPolicyEffectiveAt(old).build();
        policy.setId(id);
        when(repository.lockById(id)).thenReturn(Optional.of(policy));
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
        when(repository.lockById(id)).thenReturn(Optional.of(policy));
        when(repository.save(policy)).thenReturn(policy);
        service.update(id, FacilityPolicyUpdateRequest.builder().returnNoticeDays(2).build());
        assertEquals(old, policy.getCancellationPolicyEffectiveAt());
    }
}
