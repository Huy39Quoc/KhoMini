package com.storehub.dto.response;

import lombok.*;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CatalogOverviewResponse {
    private List<FacilityResponse> facilities;
    private List<UnitTypeCatalogResponse> unitTypes;
}