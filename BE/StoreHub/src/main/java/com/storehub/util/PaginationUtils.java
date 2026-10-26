package com.storehub.util;

import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

import java.util.Map;
import java.util.Locale;

public final class PaginationUtils {

    public static final int MAX_PAGE_SIZE = 100;

    private PaginationUtils() {
    }

    public static void validatePage(int page, int size) {
        if (page < 0 || size < 1 || size > MAX_PAGE_SIZE) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
    }

    public static Sort.Direction direction(String sortDir) {
        if (sortDir == null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        return switch (sortDir.trim().toLowerCase(Locale.ROOT)) {
            case "asc" -> Sort.Direction.ASC;
            case "desc" -> Sort.Direction.DESC;
            default -> throw new AppException(ErrorCode.INVALID_REQUEST);
        };
    }

    public static String resolveSortProperty(String sortBy, Map<String, String> allowedProperties) {
        if (sortBy == null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        String requested = sortBy.trim();
        return allowedProperties.entrySet().stream()
                .filter(entry -> entry.getKey().equalsIgnoreCase(requested))
                .map(Map.Entry::getValue)
                .findFirst()
                .orElseThrow(() -> new AppException(ErrorCode.INVALID_REQUEST));
    }

    public static PageRequest pageRequest(int page, int size) {
        validatePage(page, size);
        return PageRequest.of(page, size);
    }

    public static PageRequest pageRequest(
            int page,
            int size,
            String sortBy,
            String sortDir,
            Map<String, String> allowedProperties
    ) {
        validatePage(page, size);
        String property = resolveSortProperty(sortBy, allowedProperties);
        return PageRequest.of(page, size, Sort.by(direction(sortDir), property));
    }
}
