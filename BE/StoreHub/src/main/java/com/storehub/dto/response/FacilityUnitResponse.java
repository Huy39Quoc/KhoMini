package com.storehub.dto.response;

import com.storehub.enums.UnitStatus;
import java.util.UUID;

public record FacilityUnitResponse(
        UUID id,
        String unitCode,
        String floorLevel,
        UUID unitTypeId,
        String unitType,
        UnitStatus status
) {}