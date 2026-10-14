package com.storehub.dto.response;

import com.storehub.enums.FacilityStatus;
import lombok.*;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FacilityResponse {
    private UUID id;
    private String name;
    private String code;
    private String address;
    private String city;
    private String contactPhone;
    private String email;

    private UUID managerId;
    private String managerName;

    private FacilityStatus status;
    private LocalTime openTime;
    private LocalTime closeTime;
    private String description;

    private Boolean airConditioned24h;
    private String imageUrl;
    private java.util.List<String> images;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public String getImageUrl() {
        if (imageUrl != null && !imageUrl.isBlank()) {
            return imageUrl;
        }
        if (images != null && !images.isEmpty()) {
            return images.get(0);
        }
        return null;
    }
}
