package com.storehub.exception;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(AppException.class)
    public ResponseEntity<Map<String, Object>> handleAppException(AppException ex) {

        ErrorCode errorCode = ex.getErrorCode();

        Map<String, Object> response = new LinkedHashMap<>();

        response.put("timestamp", LocalDateTime.now());
        response.put("status", errorCode.getHttpStatus().value());
        response.put("code", errorCode.getCode());
        response.put("error", errorCode.getHttpStatus().getReasonPhrase());
        response.put("message", errorCode.getMessage());

        return ResponseEntity
                .status(errorCode.getHttpStatus())
                .body(response);
    }
}