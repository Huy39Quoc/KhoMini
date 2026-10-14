package com.storehub.entity;

import com.storehub.enums.FacilityStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalTime;

@Entity
@Table(name = "facilities")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Facility extends BaseEntity {

    @Column(name = "name", nullable = false, length = 150)
    private String name;

    @Column(name = "code", nullable = false, unique = true, length = 30)
    private String code;

    @Column(name = "address", nullable = false, length = 255)
    private String address;

    @Column(name = "city", length = 50)
    private String city;

    @Column(name = "contact_phone", length = 20)
    private String contactPhone;

    @Column(name = "email", length = 150)
    private String email;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "manager_id")
    private User manager;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private FacilityStatus status = FacilityStatus.ACTIVE;

    @Column(name = "open_time", nullable = false)
    @Builder.Default
    private LocalTime openTime = LocalTime.of(8, 0);

    @Column(name = "close_time", nullable = false)
    @Builder.Default
    private LocalTime closeTime = LocalTime.of(20, 0);

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    // Applies to every storage unit in this facility. Existing facilities default to false
    // until an administrator confirms that cooling is available around the clock.
    @Column(name = "air_conditioned_24h", nullable = false)
    @Builder.Default
    private Boolean airConditioned24h = false;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "images", columnDefinition = "TEXT")
    private String images;

    public java.util.List<String> getImageList() {
        if (images != null && !images.trim().isEmpty()) {
            return java.util.Arrays.stream(images.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .collect(java.util.stream.Collectors.toList());
        }
        if (imageUrl != null && !imageUrl.trim().isEmpty()) {
            return java.util.List.of(imageUrl);
        }
        return java.util.Collections.emptyList();
    }

    public void assignImages(java.util.List<String> list) {
        if (list == null || list.isEmpty()) {
            this.images = null;
        } else {
            this.images = String.join(",", list);
        }
    }
}
