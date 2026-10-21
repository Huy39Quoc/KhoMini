package com.storehub.service;

import com.storehub.exception.ErrorCode;
import com.storehub.exception.GlobalExceptionHandler;
import org.hibernate.exception.ConstraintViolationException;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class StorageUnitUniqueConstraintResponseTest {
    @Test
    void concurrentDuplicateUnitCreationReturnsTheSameErrorAsTheExistsCheck() {
        ConstraintViolationException cause = mock(ConstraintViolationException.class);
        when(cause.getConstraintName()).thenReturn("uq_storage_units_facility_code");
        var response = new GlobalExceptionHandler().handleDataIntegrity(
                new DataIntegrityViolationException("duplicate storage unit", cause));

        assertEquals(409, response.getStatusCode().value());
        assertEquals(ErrorCode.UNIT_CODE_EXISTED.getCode(), response.getBody().get("code"));
    }
}
