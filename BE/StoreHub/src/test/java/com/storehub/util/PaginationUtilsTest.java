package com.storehub.util;

import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class PaginationUtilsTest {

    @Test
    void rejectsInvalidPageSizeDirectionAndSortProperty() {
        assertInvalid(() -> PaginationUtils.pageRequest(-1, 10));
        assertInvalid(() -> PaginationUtils.pageRequest(0, 0));
        assertInvalid(() -> PaginationUtils.pageRequest(0, 101));
        assertInvalid(() -> PaginationUtils.pageRequest(
                0, 10, "createdAt", "sideways", Map.of("createdAt", "createdAt")));
        assertInvalid(() -> PaginationUtils.pageRequest(
                0, 10, "password", "asc", Map.of("createdAt", "createdAt")));
    }

    @Test
    void resolvesAllowedAliasAndDirection() {
        PageRequest request = PaginationUtils.pageRequest(
                2, 25, "facilityName", "DESC", Map.of("facilityName", "facility.name"));

        assertEquals(2, request.getPageNumber());
        assertEquals(25, request.getPageSize());
        assertEquals(Sort.Direction.DESC,
                request.getSort().getOrderFor("facility.name").getDirection());
    }

    private void assertInvalid(Runnable action) {
        AppException exception = assertThrows(AppException.class, action::run);
        assertEquals(ErrorCode.INVALID_REQUEST, exception.getErrorCode());
    }
}
