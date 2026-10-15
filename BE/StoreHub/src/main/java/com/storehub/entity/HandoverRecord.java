package com.storehub.entity;

import com.storehub.util.StringListAttributeConverter;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "handover_records")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HandoverRecord extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id", nullable = false)
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "staff_id", nullable = false)
    private User staff;

    @Column(name = "record_type", nullable = false, length = 30)
    private String recordType;

    @Column(name = "unit_condition")
    private String unitCondition;

    @Column(name = "notes")
    private String notes;

    @Column(name = "damage_fee", precision = 12, scale = 2)
    private BigDecimal damageFee;

    @Column(name = "damage_reason")
    private String damageReason;

    @Column(name = "recorded_at", nullable = false)
    private LocalDateTime recordedAt;

    @Convert(converter = StringListAttributeConverter.class)
    @Column(name = "photos", columnDefinition = "TEXT")
    @Builder.Default
    private List<String> photos = new ArrayList<>();

    @Deprecated
    public List<String> getPhotoList() {
        return photos != null ? photos : List.of();
    }

    @Deprecated
    public void assignPhotos(List<String> list) {
        this.photos = list != null ? list : new ArrayList<>();
    }
}