package com.storehub.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum HandoverUnitCondition {
    GOOD("Tốt / sạch sẽ"),
    DAMAGED("Hư hỏng"),
    NEEDS_CLEANING("Cần vệ sinh");

    private final String label;

    @JsonCreator
    public static HandoverUnitCondition fromCode(String code) {
        return valueOf(code);
    }
}
