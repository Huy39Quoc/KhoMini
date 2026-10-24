package com.storehub.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum HandoverLockCondition {
    LOCKED_WORKING("Đã khóa & hoạt động tốt"),
    BROKEN("Hỏng / cần sửa chữa"),
    UNLOCKED("Chưa khóa");

    private final String label;

    @JsonCreator
    public static HandoverLockCondition fromCode(String code) {
        return valueOf(code);
    }
}
