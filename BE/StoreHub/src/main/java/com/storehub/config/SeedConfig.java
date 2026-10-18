package com.storehub.config;

import com.storehub.entity.Facility;
import com.storehub.entity.Role;
import com.storehub.entity.User;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.RoleRepository;
import com.storehub.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.transaction.annotation.Transactional;

@Component
@ConditionalOnProperty(name = "seed.users.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
@Slf4j
public class SeedConfig implements ApplicationRunner {

    @Value("${seed.admin-password}")
    private String adminPassword;

    @Value("${seed.facility-manager-password}")
    private String facilityManagerPassword;

    @Value("${seed.business-manager-password}")
    private String businessManagerPassword;

    @Value("${seed.staff-password}")
    private String staffPassword;

    @Value("${seed.customer-password}")
    private String customerPassword;

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final FacilityRepository facilityRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        seedUsers();
    }

    private void seedUsers() {

        // 5 tài khoản mặc định chỉ tạo khi DB chưa có user nào
        if (userRepository.count() > 0) {
            log.info("Users already seeded — skipping");
            seedTestAccounts();
            return;
        }

        log.info("Seeding default users...");

        createUser(
                "admin",
                "admin@gmail.com",
                adminPassword,
                "System Administrator",
                "0371234567",
                "ADMIN"

        );

        createUser(
                "facility_manager",
                "facility@gmail.com",
                facilityManagerPassword,
                "System Facility Manager",
                "0372345678",
                "FACILITY_MANAGER"
        );

        createUser(
                "business_manager",
                "business@gmail.com",
                businessManagerPassword,
                "System Manager",
                "0373456789",
                "BUSINESS_MANAGER"
        );

        createUser(
                "staff",
                "staff@gmail.com",
                staffPassword,
                "System Staff",
                "0374567890",
                "STAFF"
        );

        createUser(
                "customer",
                "customer@gmail.com",
                customerPassword,
                "System Customer",
                "0373214567",
                "CUSTOMER"
        );

        log.info("Default users seeded successfully");
        seedTestAccounts();
    }

    /**
     * Tài khoản quản lý cơ sở và nhân viên bổ sung để test nhiều cơ sở.
     * Mật khẩu dùng chung với tài khoản mặc định cùng vai trò. Idempotent: thiếu tài khoản nào
     * thì tạo tài khoản đó, và chỉ gắn cơ sở khi tài khoản/cơ sở chưa có người được gắn
     * (không ghi đè phân công đã làm tay).
     */
    private void seedTestAccounts() {
        // Tài khoản mặc định: gắn vào cơ sở D1 nếu chưa được gắn
        linkManager("facility@gmail.com", "HCM-D1");
        linkStaff("staff@gmail.com", "HCM-D1");

        createUserIfMissing("facility_manager2", "facility2@gmail.com", facilityManagerPassword,
                "Facility Manager District 7", "0372345681", "FACILITY_MANAGER");
        linkManager("facility2@gmail.com", "HCM-D7");

        createUserIfMissing("facility_manager3", "facility3@gmail.com", facilityManagerPassword,
                "Facility Manager Thu Duc", "0372345682", "FACILITY_MANAGER");
        linkManager("facility3@gmail.com", "HCM-TD");

        createUserIfMissing("staff2", "staff2@gmail.com", staffPassword,
                "Staff District 1 (2)", "0374567891", "STAFF");
        linkStaff("staff2@gmail.com", "HCM-D1");

        createUserIfMissing("staff3", "staff3@gmail.com", staffPassword,
                "Staff District 7", "0374567892", "STAFF");
        linkStaff("staff3@gmail.com", "HCM-D7");

        // Cố ý KHÔNG gắn cơ sở: dùng để test chức năng "Thêm nhân viên" của quản lý cơ sở.
        createUserIfMissing("staff4", "staff4@gmail.com", staffPassword,
                "Staff Chua Phan Cong", "0374567893", "STAFF");
    }

    private void createUserIfMissing(
            String username, String email, String rawPassword,
            String fullName, String phone, String roleName
    ) {
        if (userRepository.findByEmail(email).isPresent()) {
            return;
        }
        createUser(username, email, rawPassword, fullName, phone, roleName);
    }

    private void linkManager(String email, String facilityCode) {
        User user = userRepository.findByEmail(email).orElse(null);
        Facility facility = facilityRepository.findByCode(facilityCode).orElse(null);
        if (user == null || facility == null
                || user.getFacility() != null || facility.getManager() != null) {
            return;
        }
        facility.setManager(user);
        user.setFacility(facility);
        facilityRepository.save(facility);
        userRepository.save(user);
        log.info("Linked manager {} to facility {}", email, facilityCode);
    }

    private void linkStaff(String email, String facilityCode) {
        User user = userRepository.findByEmail(email).orElse(null);
        Facility facility = facilityRepository.findByCode(facilityCode).orElse(null);
        if (user == null || facility == null || user.getFacility() != null) {
            return;
        }
        user.setFacility(facility);
        userRepository.save(user);
        log.info("Linked staff {} to facility {}", email, facilityCode);
    }

    private void createUser(
            String username,
            String email,
            String rawPassword,
            String fullName,
            String phone,
            String roleName
    ) {
        Role role = roleRepository.findByName(roleName)
                .orElseThrow(() ->
                        new RuntimeException("Role not found: " + roleName)
                );

        User user = User.builder()
                .username(username)
                .email(email)
                .password(passwordEncoder.encode(rawPassword))
                .fullName(fullName)
                .phone(phone)
                .role(role)
                .isActive(true)
                .build();

        userRepository.save(user);

        log.info("Created user: {} ({})", username, email);
    }
}
