package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HandoverResponse {

    private UUID bookingId;

    private String bookingCode;

    private UUID storageUnitId;

    private String unitCode;

    private String recordType;

    private String unitCondition;

    private String lockCondition;

    private String notes;

    private BookingStatus bookingStatus;

    private String unitStatus;

    private UUID staffId;

    private String staffName;

    private LocalDateTime recordedAt;

    private String message;
}