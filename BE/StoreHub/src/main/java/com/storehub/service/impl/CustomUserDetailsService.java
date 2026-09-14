package com.storehub.service.impl;

import com.storehub.entity.RolePermission;
import com.storehub.entity.User;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.RolePermissionRepository;
import com.storehub.repository.UserRepository;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;
    private final RolePermissionRepository rolePermissionRepository;

    @Override
    @Transactional
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + email));
        if (!user.getIsActive()) {
            throw new AppException(ErrorCode.USER_NOT_FOUND);
        }

        List<SimpleGrantedAuthority> authorities = new ArrayList<>();

        if (user.getRole() != null) {
            authorities.add(new SimpleGrantedAuthority("ROLE_" + user.getRole().getName()));

            if (Boolean.TRUE.equals(user.getRole().getIsActive())) {
                List<RolePermission> rolePermissions = rolePermissionRepository
                        .findAllByRole_IdAndIsActiveTrueAndPermission_IsActiveTrue(user.getRole().getId());

                for (RolePermission rp : rolePermissions) {
                    if (rp.getPermission() != null && rp.getPermission().getName() != null) {
                        authorities.add(new SimpleGrantedAuthority(rp.getPermission().getName()));
                    }
                }
            }
        }

        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getEmail())
                .password(user.getPassword())
                .authorities(authorities)
                .build();
    }
}
