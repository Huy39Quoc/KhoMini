package com.storehub.entity;

import com.storehub.enums.WaitlistStatus;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(
    name = "waitlists",
    indexes = {
        @Index(name = "idx_waitlist_facility_unittype_status",
               columnList = "facility_id, unit_type_id, status")
    }
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Waitlist extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "facility_id", nullable = false)
    private Facility facility;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "unit_type_id", nullable = false)
    private UnitType unitType;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    @Builder.Default
    private WaitlistStatus status = WaitlistStatus.WAITING;
}
