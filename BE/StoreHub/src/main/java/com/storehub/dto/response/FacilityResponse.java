package com.storehub.dto.response;

import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FacilityResponse {
    private UUID id;
    private String name;
    private String address;
    private String city;
    private String contactPhone;
    private LocalDateTime createdAt;
}