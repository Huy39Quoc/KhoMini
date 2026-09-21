package com.storehub.entity;

import com.storehub.entity.User;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
@RequiredArgsConstructor
public class FacilityAccess {

    private final UserRepository users;

    public User require(String email, UUID facilityId) {
        User user = users.findByEmail(email)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        if (facilityId == null
                || user.getFacility() == null
                || !facilityId.equals(user.getFacility().getId())) {
            throw new AppException(ErrorCode.FORBIDDEN);
        }

        return user;
    }
}