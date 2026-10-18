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
                "business_manager",
                "business@gmail.com",
                businessManagerPassword,
                "System Manager",
                "0373456789",
                "BUSINESS_MANAGER"
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
     * Tài khoản quản lý cơ sở và nhân viên, đặt tên theo số thứ tự (facility1.., staff1..).
     * Mật khẩu dùng chung theo vai trò. Idempotent: thiếu tài khoản nào thì tạo; tài khoản cũ
     * (facility@, staff@, facility_manager2...) được đổi tên theo quy ước mới; chỉ gắn cơ sở khi
     * tài khoản và cơ sở chưa được gắn (không ghi đè phân công đã làm tay).
     */
    private void seedTestAccounts() {
        renameLegacyEmail("facility@gmail.com", "facility1@gmail.com");
        renameLegacyEmail("staff@gmail.com", "staff1@gmail.com");

        ensureAccount("facility1", "facility1@gmail.com", facilityManagerPassword,
                "Facility 1", "0372345678", "FACILITY_MANAGER");
        linkManager("facility1@gmail.com", "HCM-D1");

        ensureAccount("facility2", "facility2@gmail.com", facilityManagerPassword,
                "Facility 2", "0372345681", "FACILITY_MANAGER");
        linkManager("facility2@gmail.com", "HCM-D7");

        ensureAccount("facility3", "facility3@gmail.com", facilityManagerPassword,
                "Facility 3", "0372345682", "FACILITY_MANAGER");
        linkManager("facility3@gmail.com", "HCM-TD");

        ensureAccount("staff1", "staff1@gmail.com", staffPassword,
                "Staff 1", "0374567890", "STAFF");
        linkStaff("staff1@gmail.com", "HCM-D1");

        ensureAccount("staff2", "staff2@gmail.com", staffPassword,
                "Staff 2", "0374567891", "STAFF");
        linkStaff("staff2@gmail.com", "HCM-D1");

        ensureAccount("staff3", "staff3@gmail.com", staffPassword,
                "Staff 3", "0374567892", "STAFF");
        linkStaff("staff3@gmail.com", "HCM-D7");

        // Cố ý KHÔNG gắn cơ sở: dùng để test chức năng "Thêm nhân viên" của quản lý cơ sở.
        ensureAccount("staff4", "staff4@gmail.com", staffPassword,
                "Staff 4", "0374567893", "STAFF");
    }

    /** Đổi email của tài khoản cũ sang quy ước mới (giữ nguyên mật khẩu, vai trò, cơ sở). */
    private void renameLegacyEmail(String oldEmail, String newEmail) {
        User user = userRepository.findByEmail(oldEmail).orElse(null);
        if (user == null || userRepository.existsByEmail(newEmail)) {
            return;
        }
        user.setEmail(newEmail);
        userRepository.save(user);
        log.info("Renamed account {} -> {}", oldEmail, newEmail);
    }

    /** Tạo tài khoản nếu chưa có; nếu đã có thì đồng bộ tên đăng nhập và họ tên theo quy ước. */
    private void ensureAccount(
            String username, String email, String rawPassword,
            String fullName, String phone, String roleName
    ) {
        User existing = userRepository.findByEmail(email).orElse(null);
        if (existing == null) {
            createUser(username, email, rawPassword, fullName, phone, roleName);
            return;
        }
        boolean changed = false;
        if (!fullName.equals(existing.getFullName())) {
            existing.setFullName(fullName);
            changed = true;
        }
        if (!username.equals(existing.getUsername())
                && !userRepository.existsByUsernameAndIdNot(username, existing.getId())) {
            existing.setUsername(username);
            changed = true;
        }
        if (changed) {
            userRepository.save(existing);
            log.info("Updated seeded account naming: {}", email);
        }
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
