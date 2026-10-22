package com.storehub.config;

import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

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
    private final StorageUnitRepository storageUnitRepository;
    private final BookingRepository bookingRepository;
    private final PaymentRepository paymentRepository;
    private final RefundRequestRepository refundRequestRepository;
    private final HandoverRecordRepository handoverRecordRepository;
    private final SupportTicketRepository supportTicketRepository;
    private final ActivityLogRepository activityLogRepository;
    private final WaitlistRepository waitlistRepository;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        seedUsers();
        seedOperationalData();
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

        // Quản lý cơ sở dự phòng / chưa gắn cơ sở (dùng để test Admin "Gán quản lý cho cơ sở")
        ensureAccount("facility4", "facility4@gmail.com", facilityManagerPassword,
                "Facility 4", "0372345683", "FACILITY_MANAGER");

        ensureAccount("facility5", "facility5@gmail.com", facilityManagerPassword,
                "Facility 5", "0372345684", "FACILITY_MANAGER");

        // Nhân viên cho cơ sở Thủ Đức (HCM-TD)
        ensureAccount("staff5", "staff5@gmail.com", staffPassword,
                "Staff 5", "0374567894", "STAFF");
        linkStaff("staff5@gmail.com", "HCM-TD");

        ensureAccount("staff6", "staff6@gmail.com", staffPassword,
                "Staff 6", "0374567895", "STAFF");
        linkStaff("staff6@gmail.com", "HCM-TD");

        // Nhân viên thứ hai cho cơ sở Quận 7 (HCM-D7)
        ensureAccount("staff7", "staff7@gmail.com", staffPassword,
                "Staff 7", "0374567896", "STAFF");
        linkStaff("staff7@gmail.com", "HCM-D7");

        // Nhân viên dự phòng KHÔNG gắn cơ sở (dùng để test Quản lý cơ sở thêm nhân viên)
        ensureAccount("staff8", "staff8@gmail.com", staffPassword,
                "Staff 8", "0374567897", "STAFF");

        ensureAccount("staff9", "staff9@gmail.com", staffPassword,
                "Staff 9", "0374567898", "STAFF");
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

    private void seedOperationalData() {
        if (bookingRepository.existsByBookingCode("BK-TEST-ACTIVE-01")) {
            log.info("Operational test data already seeded — skipping");
            return;
        }

        log.info("Seeding rich operational test data (Bookings, Units, Payments, Tickets, Logs)...");

        // 1. Tạo thêm tài khoản khách hàng kiểm thử
        ensureAccount("customer2", "customer2@gmail.com", customerPassword,
                "Nguyen Van An", "0912345678", "CUSTOMER");
        ensureAccount("customer3", "customer3@gmail.com", customerPassword,
                "Tran Thi Binh", "0987654321", "CUSTOMER");

        User customer1 = userRepository.findByEmail("customer@gmail.com").orElse(null);
        User customer2 = userRepository.findByEmail("customer2@gmail.com").orElse(null);
        User customer3 = userRepository.findByEmail("customer3@gmail.com").orElse(null);
        User staff1 = userRepository.findByEmail("staff1@gmail.com").orElse(null);
        User admin = userRepository.findByEmail("admin@gmail.com").orElse(null);
        User business = userRepository.findByEmail("business@gmail.com").orElse(null);
        User facilityManager1 = userRepository.findByEmail("facility1@gmail.com").orElse(null);

        Facility hcmD1 = facilityRepository.findByCode("HCM-D1").orElse(null);
        Facility hcmD7 = facilityRepository.findByCode("HCM-D7").orElse(null);
        Facility hcmTd = facilityRepository.findByCode("HCM-TD").orElse(null);

        if (customer1 == null || hcmD1 == null) {
            log.warn("Required seed users or facilities missing, cannot seed operational data");
            return;
        }

        LocalDateTime now = LocalDateTime.now();
        LocalDate today = LocalDate.now();

        // 2. Dữ liệu ngăn kho và đơn thuê tại HCM-D1 (Quận 1)
        StorageUnit suS101 = storageUnitRepository.findByFacility_IdAndUnitCode(hcmD1.getId(), "S-101").orElse(null);
        StorageUnit suM201 = storageUnitRepository.findByFacility_IdAndUnitCode(hcmD1.getId(), "M-201").orElse(null);
        StorageUnit suL301 = storageUnitRepository.findByFacility_IdAndUnitCode(hcmD1.getId(), "L-301").orElse(null);
        StorageUnit suS102 = storageUnitRepository.findByFacility_IdAndUnitCode(hcmD1.getId(), "S-102").orElse(null);
        StorageUnit suM202 = storageUnitRepository.findByFacility_IdAndUnitCode(hcmD1.getId(), "M-202").orElse(null);
        StorageUnit suL302 = storageUnitRepository.findByFacility_IdAndUnitCode(hcmD1.getId(), "L-302").orElse(null);
        if (suL302 != null) {
            suL302.setStatus(UnitStatus.OCCUPIED);
            storageUnitRepository.save(suL302);
        }

        // Booking 1: ACTIVE tại S-101 (Cho customer@gmail.com - Thao tác ngay Flow 3: Khóa thông minh PIN 123456, QR ra vào cổng)
        Booking bkActive01 = null;
        if (suS101 != null) {
            suS101.setStatus(UnitStatus.OCCUPIED);
            storageUnitRepository.save(suS101);

            bkActive01 = Booking.builder()
                    .cancellationFullRefundHours(48)
                    .cancellationPartialRefundHours(24)
                    .cancellationPartialRefundPercent(50.0)
                    .cancellationPolicyEffectiveAt(now.minusDays(30))
                    .cancellationPolicyCapturedAt(now.minusDays(10))
                    .cancellationPolicyLegacy(false)
                    .bookingCode("BK-TEST-ACTIVE-01")
                    .customer(customer1)
                    .storageUnit(suS101)
                    .unitAssignmentConfirmed(true)
                    .startDate(today.minusDays(10))
                    .endDate(today.plusDays(20))
                    .rentalMonths(1)
                    .totalRentalFee(new BigDecimal("500000.00"))
                    .quotedDepositAmount(new BigDecimal("500000.00"))
                    .quotedManagementFee(new BigDecimal("50000.00"))
                    .depositPaid(new BigDecimal("500000.00"))
                    .status(BookingStatus.ACTIVE)
                    .accessPin(passwordEncoder.encode("123456"))
                    .unitLocked(true)
                    .pinFailedAttempts(0)
                    .pinUpdatedAt(now.minusDays(10))
                    .assignedCheckInStaff(staff1)
                    .handedOverByStaffId(staff1 != null ? staff1.getId() : null)
                    .handoverTime(now.minusDays(10))
                    .termsAccepted(true)
                    .prohibitedItemsAccepted(true)
                    .termsAcceptedAt(now.minusDays(10))
                    .termsVersion("v2026.1")
                    .build();
            bkActive01 = bookingRepository.save(bkActive01);

            if (staff1 != null) {
                handoverRecordRepository.save(HandoverRecord.builder()
                        .booking(bkActive01)
                        .staff(staff1)
                        .recordType("CHECK_IN")
                        .unitCondition("Ngăn sạch sẽ, khóa thông minh hoạt động tốt, đã hướng dẫn khách cài đặt mã PIN.")
                        .notes("Bàn giao chìa khóa điện tử thành công.")
                        .recordedAt(now.minusDays(10))
                        .build());
            }

            paymentRepository.save(Payment.builder()
                    .transactionId("TXN-TEST-BK01-RENTAL")
                    .booking(bkActive01)
                    .amount(new BigDecimal("500000.00"))
                    .paymentType(PaymentType.RENTAL_FEE)
                    .status(PaymentStatus.PAID)
                    .paymentMethod("VNPAY")
                    .paymentTime(now.minusDays(10))
                    .note("Phí thuê ngăn S-101")
                    .build());

            paymentRepository.save(Payment.builder()
                    .transactionId("TXN-TEST-BK01-DEPOSIT")
                    .booking(bkActive01)
                    .amount(new BigDecimal("500000.00"))
                    .paymentType(PaymentType.DEPOSIT)
                    .status(PaymentStatus.PAID)
                    .paymentMethod("VNPAY")
                    .paymentTime(now.minusDays(10))
                    .note("Tiền cọc ngăn S-101")
                    .build());
        }

        // Booking 2: ACTIVE sắp hết hạn tại M-201 (Cho customer@gmail.com - Thao tác ngay Gia hạn Flow 4 hoặc Yêu cầu trả kho Flow 5)
        Booking bkActive02 = null;
        if (suM201 != null) {
            suM201.setStatus(UnitStatus.OCCUPIED);
            storageUnitRepository.save(suM201);

            bkActive02 = Booking.builder()
                    .cancellationFullRefundHours(48)
                    .cancellationPartialRefundHours(24)
                    .cancellationPartialRefundPercent(50.0)
                    .cancellationPolicyEffectiveAt(now.minusDays(30))
                    .cancellationPolicyCapturedAt(now.minusDays(28))
                    .cancellationPolicyLegacy(false)
                    .bookingCode("BK-TEST-ACTIVE-02")
                    .customer(customer1)
                    .storageUnit(suM201)
                    .unitAssignmentConfirmed(true)
                    .startDate(today.minusDays(28))
                    .endDate(today.plusDays(2))
                    .rentalMonths(1)
                    .totalRentalFee(new BigDecimal("1200000.00"))
                    .quotedDepositAmount(new BigDecimal("1200000.00"))
                    .quotedManagementFee(new BigDecimal("50000.00"))
                    .depositPaid(new BigDecimal("1200000.00"))
                    .status(BookingStatus.ACTIVE)
                    .accessPin(passwordEncoder.encode("888999"))
                    .unitLocked(true)
                    .pinFailedAttempts(0)
                    .pinUpdatedAt(now.minusDays(28))
                    .assignedCheckInStaff(staff1)
                    .handedOverByStaffId(staff1 != null ? staff1.getId() : null)
                    .handoverTime(now.minusDays(28))
                    .termsAccepted(true)
                    .prohibitedItemsAccepted(true)
                    .termsAcceptedAt(now.minusDays(28))
                    .termsVersion("v2026.1")
                    .build();
            bkActive02 = bookingRepository.save(bkActive02);

            if (staff1 != null) {
                handoverRecordRepository.save(HandoverRecord.builder()
                        .booking(bkActive02)
                        .staff(staff1)
                        .recordType("CHECK_IN")
                        .unitCondition("Kho thoáng mát, cửa khóa thông minh hoạt động bình thường.")
                        .recordedAt(now.minusDays(28))
                        .build());
            }

            paymentRepository.save(Payment.builder()
                    .transactionId("TXN-TEST-BK02-RENTAL")
                    .booking(bkActive02)
                    .amount(new BigDecimal("1200000.00"))
                    .paymentType(PaymentType.RENTAL_FEE)
                    .status(PaymentStatus.PAID)
                    .paymentMethod("VNPAY")
                    .paymentTime(now.minusDays(28))
                    .note("Phí thuê ngăn M-201")
                    .build());

            paymentRepository.save(Payment.builder()
                    .transactionId("TXN-TEST-BK02-DEPOSIT")
                    .booking(bkActive02)
                    .amount(new BigDecimal("1200000.00"))
                    .paymentType(PaymentType.DEPOSIT)
                    .status(PaymentStatus.PAID)
                    .paymentMethod("VNPAY")
                    .paymentTime(now.minusDays(28))
                    .note("Tiền cọc ngăn M-201")
                    .build());
        }

        // Booking 3: CONFIRMED tại L-301 (Awaiting Handover hôm nay - Thao tác Quản lý gán ngăn/Staff check-in Flow 2)
        Booking bkConfirmed01 = null;
        if (suL301 != null && customer2 != null) {
            suL301.setStatus(UnitStatus.RESERVED);
            storageUnitRepository.save(suL301);

            bkConfirmed01 = Booking.builder()
                    .cancellationFullRefundHours(48)
                    .cancellationPartialRefundHours(24)
                    .cancellationPartialRefundPercent(50.0)
                    .cancellationPolicyEffectiveAt(now.minusDays(30))
                    .cancellationPolicyCapturedAt(now.minusHours(2))
                    .cancellationPolicyLegacy(false)
                    .bookingCode("BK-TEST-CONFIRMED-01")
                    .customer(customer2)
                    .storageUnit(suL301)
                    .unitAssignmentConfirmed(true)
                    .startDate(today)
                    .scheduledCheckInTime(now.withHour(14).withMinute(0))
                    .endDate(today.plusMonths(1))
                    .rentalMonths(1)
                    .totalRentalFee(new BigDecimal("2500000.00"))
                    .quotedDepositAmount(new BigDecimal("2500000.00"))
                    .depositPaid(new BigDecimal("2500000.00"))
                    .status(BookingStatus.CONFIRMED)
                    .assignedCheckInStaff(staff1)
                    .termsAccepted(true)
                    .prohibitedItemsAccepted(true)
                    .termsAcceptedAt(now.minusHours(2))
                    .termsVersion("v2026.1")
                    .build();
            bkConfirmed01 = bookingRepository.save(bkConfirmed01);

            paymentRepository.save(Payment.builder()
                    .transactionId("TXN-TEST-BK03-RENTAL")
                    .booking(bkConfirmed01)
                    .amount(new BigDecimal("2500000.00"))
                    .paymentType(PaymentType.RENTAL_FEE)
                    .status(PaymentStatus.PAID)
                    .paymentMethod("VNPAY")
                    .paymentTime(now.minusHours(2))
                    .note("Phí thuê ngăn L-301")
                    .build());

            paymentRepository.save(Payment.builder()
                    .transactionId("TXN-TEST-BK03-DEPOSIT")
                    .booking(bkConfirmed01)
                    .amount(new BigDecimal("2500000.00"))
                    .paymentType(PaymentType.DEPOSIT)
                    .status(PaymentStatus.PAID)
                    .paymentMethod("VNPAY")
                    .paymentTime(now.minusHours(2))
                    .note("Tiền cọc ngăn L-301")
                    .build());
        }

        // Booking 4: COMPLETED tại S-102 (Đã trả kho, ngăn UNDER_MAINTENANCE, chờ Quản lý duyệt hoàn cọc Flow 5)
        Booking bkCompleted01 = null;
        if (suS102 != null && customer2 != null) {
            suS102.setStatus(UnitStatus.UNDER_MAINTENANCE);
            storageUnitRepository.save(suS102);

            bkCompleted01 = Booking.builder()
                    .cancellationFullRefundHours(48)
                    .cancellationPartialRefundHours(24)
                    .cancellationPartialRefundPercent(50.0)
                    .cancellationPolicyEffectiveAt(now.minusDays(60))
                    .cancellationPolicyCapturedAt(now.minusMonths(1).minusDays(3))
                    .cancellationPolicyLegacy(false)
                    .bookingCode("BK-TEST-COMPLETED-01")
                    .customer(customer2)
                    .storageUnit(suS102)
                    .unitAssignmentConfirmed(true)
                    .startDate(today.minusMonths(1).minusDays(3))
                    .endDate(today.minusDays(3))
                    .rentalMonths(1)
                    .totalRentalFee(new BigDecimal("500000.00"))
                    .quotedDepositAmount(new BigDecimal("500000.00"))
                    .depositPaid(new BigDecimal("500000.00"))
                    .status(BookingStatus.COMPLETED)
                    .refundBankCode("VCB")
                    .refundAccountNumber("0123456789")
                    .refundAccountName("NGUYEN VAN AN")
                    .handoverTime(now.minusMonths(1).minusDays(3))
                    .returnTime(now.minusDays(1))
                    .termsAccepted(true)
                    .prohibitedItemsAccepted(true)
                    .build();
            bkCompleted01 = bookingRepository.save(bkCompleted01);

            if (staff1 != null) {
                handoverRecordRepository.save(HandoverRecord.builder()
                        .booking(bkCompleted01)
                        .staff(staff1)
                        .recordType("CHECK_OUT")
                        .unitCondition("Kho trả nguyên vẹn, sạch sẽ, không có hư hại thiết bị.")
                        .damageFee(BigDecimal.ZERO)
                        .recordedAt(now.minusDays(1))
                        .build());
            }

            Payment origDepPayment = Payment.builder()
                    .transactionId("TXN-TEST-BK04-DEPOSIT")
                    .booking(bkCompleted01)
                    .amount(new BigDecimal("500000.00"))
                    .paymentType(PaymentType.DEPOSIT)
                    .status(PaymentStatus.PAID)
                    .paymentMethod("VNPAY")
                    .paymentTime(now.minusMonths(1).minusDays(3))
                    .note("Tiền cọc ban đầu ngăn S-102")
                    .build();
            origDepPayment = paymentRepository.save(origDepPayment);

            String reqId = "REQ" + UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase();
            Payment refundPayment = Payment.builder()
                    .transactionId("RF-" + reqId)
                    .booking(bkCompleted01)
                    .amount(new BigDecimal("500000.00"))
                    .paymentType(PaymentType.DEPOSIT)
                    .status(PaymentStatus.REFUND_PENDING)
                    .paymentMethod("BANK_TRANSFER")
                    .note("Hoàn tiền cọc trả kho S-102")
                    .paymentTime(now.minusDays(1))
                    .build();
            refundPayment = paymentRepository.save(refundPayment);

            refundRequestRepository.save(RefundRequest.builder()
                    .booking(bkCompleted01)
                    .originalPayment(origDepPayment)
                    .refundPayment(refundPayment)
                    .requestId(reqId)
                    .amount(new BigDecimal("500000.00"))
                    .depositAmount(new BigDecimal("500000.00"))
                    .rentalAmount(BigDecimal.ZERO)
                    .damageDeduction(BigDecimal.ZERO)
                    .status(RefundStatus.AWAITING_BANK_TRANSFER)
                    .dueAt(now.plusDays(4))
                    .bankCode("VCB")
                    .bankAccountNumber("0123456789")
                    .bankAccountName("NGUYEN VAN AN")
                    .build());
        }

        // Booking 5: PENDING_PAYMENT tại M-202 (Để test mục Đơn chờ thanh toán: thanh toán ngay hoặc hủy đơn)
        if (suM202 != null) {
            suM202.setStatus(UnitStatus.RESERVED);
            storageUnitRepository.save(suM202);

            Booking bkPending01 = Booking.builder()
                    .cancellationFullRefundHours(48)
                    .cancellationPartialRefundHours(24)
                    .cancellationPartialRefundPercent(50.0)
                    .cancellationPolicyEffectiveAt(now.minusDays(30))
                    .cancellationPolicyCapturedAt(now.minusMinutes(5))
                    .cancellationPolicyLegacy(false)
                    .bookingCode("BK-TEST-PENDING-01")
                    .customer(customer1)
                    .storageUnit(suM202)
                    .unitAssignmentConfirmed(false)
                    .startDate(today.plusDays(1))
                    .endDate(today.plusMonths(1).plusDays(1))
                    .rentalMonths(1)
                    .totalRentalFee(new BigDecimal("1200000.00"))
                    .quotedDepositAmount(new BigDecimal("1200000.00"))
                    .quotedManagementFee(new BigDecimal("50000.00"))
                    .depositPaid(BigDecimal.ZERO)
                    .status(BookingStatus.PENDING_PAYMENT)
                    .expiresAt(now.plusMinutes(25))
                    .termsAccepted(true)
                    .prohibitedItemsAccepted(true)
                    .termsAcceptedAt(now.minusMinutes(5))
                    .termsVersion("v2026.1")
                    .build();
            bookingRepository.save(bkPending01);
        }

        // 3. Dữ liệu kho tại Quận 7 (HCM-D7) & Thủ Đức (HCM-TD) để báo cáo doanh thu & tỷ lệ lấp đầy phong phú
        Booking bkD7 = null;
        Booking bkTd = null;
        if (hcmD7 != null && customer3 != null) {
            StorageUnit suD7S101 = storageUnitRepository.findByFacility_IdAndUnitCode(hcmD7.getId(), "S-101").orElse(null);
            if (suD7S101 != null) {
                suD7S101.setStatus(UnitStatus.OCCUPIED);
                storageUnitRepository.save(suD7S101);

                bkD7 = Booking.builder()
                        .cancellationFullRefundHours(48)
                        .cancellationPartialRefundHours(24)
                        .cancellationPartialRefundPercent(50.0)
                        .cancellationPolicyEffectiveAt(now.minusDays(30))
                        .cancellationPolicyCapturedAt(now.minusDays(15))
                        .cancellationPolicyLegacy(false)
                        .bookingCode("BK-D7-ACTIVE-01")
                        .customer(customer3)
                        .storageUnit(suD7S101)
                        .unitAssignmentConfirmed(true)
                        .startDate(today.minusDays(15))
                        .endDate(today.plusDays(15))
                        .rentalMonths(1)
                        .totalRentalFee(new BigDecimal("500000.00"))
                        .quotedDepositAmount(new BigDecimal("500000.00"))
                        .depositPaid(new BigDecimal("500000.00"))
                        .status(BookingStatus.ACTIVE)
                        .accessPin(passwordEncoder.encode("112233"))
                        .unitLocked(true)
                        .termsAccepted(true)
                        .prohibitedItemsAccepted(true)
                        .build();
                bkD7 = bookingRepository.save(bkD7);

                paymentRepository.save(Payment.builder()
                        .transactionId("TXN-D7-BK01-RENTAL")
                        .booking(bkD7)
                        .amount(new BigDecimal("500000.00"))
                        .paymentType(PaymentType.RENTAL_FEE)
                        .status(PaymentStatus.PAID)
                        .paymentMethod("VNPAY")
                        .paymentTime(now.minusDays(15))
                        .note("Phí thuê ngăn D7-S101")
                        .build());
                paymentRepository.save(Payment.builder()
                        .transactionId("TXN-D7-BK01-DEPOSIT")
                        .booking(bkD7)
                        .amount(new BigDecimal("500000.00"))
                        .paymentType(PaymentType.DEPOSIT)
                        .status(PaymentStatus.PAID)
                        .paymentMethod("VNPAY")
                        .paymentTime(now.minusDays(15))
                        .note("Tiền cọc ngăn D7-S101")
                        .build());
            }
        }

        if (hcmTd != null && customer2 != null) {
            StorageUnit suTdS101 = storageUnitRepository.findByFacility_IdAndUnitCode(hcmTd.getId(), "S-101").orElse(null);
            if (suTdS101 != null) {
                suTdS101.setStatus(UnitStatus.OCCUPIED);
                storageUnitRepository.save(suTdS101);

                bkTd = Booking.builder()
                        .cancellationFullRefundHours(48)
                        .cancellationPartialRefundHours(24)
                        .cancellationPartialRefundPercent(50.0)
                        .cancellationPolicyEffectiveAt(now.minusDays(30))
                        .cancellationPolicyCapturedAt(now.minusDays(20))
                        .cancellationPolicyLegacy(false)
                        .bookingCode("BK-TD-ACTIVE-01")
                        .customer(customer2)
                        .storageUnit(suTdS101)
                        .unitAssignmentConfirmed(true)
                        .startDate(today.minusDays(20))
                        .endDate(today.plusDays(10))
                        .rentalMonths(1)
                        .totalRentalFee(new BigDecimal("500000.00"))
                        .quotedDepositAmount(new BigDecimal("500000.00"))
                        .depositPaid(new BigDecimal("500000.00"))
                        .status(BookingStatus.ACTIVE)
                        .accessPin(passwordEncoder.encode("445566"))
                        .unitLocked(true)
                        .termsAccepted(true)
                        .prohibitedItemsAccepted(true)
                        .build();
                bkTd = bookingRepository.save(bkTd);

                paymentRepository.save(Payment.builder()
                        .transactionId("TXN-TD-BK01-RENTAL")
                        .booking(bkTd)
                        .amount(new BigDecimal("500000.00"))
                        .paymentType(PaymentType.RENTAL_FEE)
                        .status(PaymentStatus.PAID)
                        .paymentMethod("VNPAY")
                        .paymentTime(now.minusDays(20))
                        .note("Phí thuê ngăn TD-S101")
                        .build());
                paymentRepository.save(Payment.builder()
                        .transactionId("TXN-TD-BK01-DEPOSIT")
                        .booking(bkTd)
                        .amount(new BigDecimal("500000.00"))
                        .paymentType(PaymentType.DEPOSIT)
                        .status(PaymentStatus.PAID)
                        .paymentMethod("VNPAY")
                        .paymentTime(now.minusDays(20))
                        .note("Tiền cọc ngăn TD-S101")
                        .build());
            }
        }

        // 4. Dữ liệu yêu cầu hỗ trợ (Support Tickets) cho Khách hàng, Nhân viên, Quản lý
        if (bkActive01 != null) {
            supportTicketRepository.save(SupportTicket.builder()
                    .ticketCode("TK-HCM-001")
                    .customer(customer1)
                    .booking(bkActive01)
                    .category(TicketCategory.PIN_CODE)
                    .title("Hỗ trợ hướng dẫn đổi mã PIN ngăn S-101")
                    .description("Tôi muốn đổi mã PIN nhưng bấm nhầm, nhờ nhân viên kỹ thuật hỗ trợ kiểm tra.")
                    .status(TicketStatus.IN_PROGRESS)
                    .priority("MEDIUM")
                    .assignedStaff(staff1)
                    .build());
        }

        if (bkActive02 != null) {
            supportTicketRepository.save(SupportTicket.builder()
                    .ticketCode("TK-HCM-002")
                    .customer(customer1)
                    .booking(bkActive02)
                    .category(TicketCategory.LOCK_ISSUE)
                    .title("Bản lề cửa ngăn kho hơi rít khi mở")
                    .description("Bản lề cửa ngăn M-201 tầng 2 hơi rít, nhờ nhân viên tra dầu bôi trơn.")
                    .status(TicketStatus.OPEN)
                    .priority("HIGH")
                    .assignedStaff(null)
                    .build());
        }

        if (bkCompleted01 != null && customer2 != null) {
            supportTicketRepository.save(SupportTicket.builder()
                    .ticketCode("TK-HCM-003")
                    .customer(customer2)
                    .booking(bkCompleted01)
                    .category(TicketCategory.FACILITY_DAMAGE)
                    .title("Vệ sinh hành lang sau khi chuyển đồ")
                    .description("Tôi đã dọn hết đồ ra ngoài, nhờ nhân viên dọn vệ sinh ngăn S-102.")
                    .status(TicketStatus.RESOLVED)
                    .resolutionNote("Nhân viên đã kiểm tra ngăn và dọn dẹp sạch sẽ.")
                    .priority("LOW")
                    .assignedStaff(staff1)
                    .build());
        }

        if (bkD7 != null && customer3 != null) {
            supportTicketRepository.save(SupportTicket.builder()
                    .ticketCode("TK-D7-001")
                    .customer(customer3)
                    .booking(bkD7)
                    .category(TicketCategory.OTHER)
                    .title("Hỏi về thủ tục ra vào ngoài giờ cơ sở Quận 7")
                    .description("Tôi muốn hỏi sau 20h cơ sở Quận 7 có nhân viên trực hỗ trợ không.")
                    .status(TicketStatus.OPEN)
                    .priority("LOW")
                    .assignedStaff(null)
                    .build());
        }

        if (bkTd != null && customer2 != null) {
            User staff5 = userRepository.findByEmail("staff5@gmail.com").orElse(null);
            supportTicketRepository.save(SupportTicket.builder()
                    .ticketCode("TK-TD-001")
                    .customer(customer2)
                    .booking(bkTd)
                    .category(TicketCategory.OTHER)
                    .title("Hỗ trợ xe đẩy hàng tại cơ sở Thủ Đức")
                    .description("Cơ sở Thủ Đức có sẵn xe đẩy hàng cho khách tự dọn đồ vào kho không?")
                    .status(TicketStatus.IN_PROGRESS)
                    .priority("MEDIUM")
                    .assignedStaff(staff5)
                    .build());
        }

        // 5. Hàng đợi (Waitlist)
        if (suL301 != null && customer3 != null) {
            if (!waitlistRepository.existsByCustomer_IdAndFacility_IdAndUnitType_IdAndStatus(
                    customer3.getId(), hcmD1.getId(), suL301.getUnitType().getId(), WaitlistStatus.WAITING)) {
                waitlistRepository.save(Waitlist.builder()
                        .customer(customer3)
                        .facility(hcmD1)
                        .unitType(suL301.getUnitType())
                        .status(WaitlistStatus.WAITING)
                        .build());
            }
        }

        // 6. Dữ liệu nhật ký kiểm toán (Activity Logs) cho Admin
        seedActivityLogs(admin, business, facilityManager1, staff1, customer1);

        log.info("Rich operational test data seeded successfully!");
    }

    private void seedActivityLogs(User admin, User business, User facility1, User staff1, User customer) {
        saveLog(admin, ActivityAction.LOGIN_SUCCESS, "Quản trị viên đăng nhập hệ thống", ActivityLogStatus.SUCCESS);
        saveLog(business, ActivityAction.LOGIN_SUCCESS, "Quản lý vận hành đăng nhập", ActivityLogStatus.SUCCESS);
        saveLog(facility1, ActivityAction.LOGIN_SUCCESS, "Quản lý cơ sở HCM-D1 đăng nhập", ActivityLogStatus.SUCCESS);
        saveLog(customer, ActivityAction.LOGIN_SUCCESS, "Khách hàng đăng nhập ứng dụng", ActivityLogStatus.SUCCESS);
        saveLog(customer, ActivityAction.RESERVATION_CREATE, "Khởi tạo đơn đặt giữ chỗ BK-TEST-ACTIVE-01", ActivityLogStatus.SUCCESS);
        saveLog(customer, ActivityAction.PAYMENT_CONFIRMED, "Thanh toán thành công đơn đặt chỗ BK-TEST-ACTIVE-01", ActivityLogStatus.SUCCESS);
        saveLog(facility1, ActivityAction.STORAGE_UNIT_ASSIGN, "Xác nhận ngăn S-101 và phân công nhân viên staff1", ActivityLogStatus.SUCCESS);
        saveLog(staff1, ActivityAction.HANDOVER_COMPLETE, "Bàn giao check-in kho cho khách hàng tại ngăn S-101", ActivityLogStatus.SUCCESS);
        saveLog(customer, ActivityAction.ACCESS_CREDENTIAL_ISSUE, "Khách hàng thiết lập mã PIN 6 số cho khóa thông minh", ActivityLogStatus.SUCCESS);
        saveLog(customer, ActivityAction.GATE_PASS_ISSUED, "Tạo mã QR ra vào cổng cơ sở HCM-D1 có hạn 60s", ActivityLogStatus.SUCCESS);
        saveLog(staff1, ActivityAction.GATE_PASS_VERIFIED, "Nhân viên quét duyệt thành công mã QR vào cổng của khách", ActivityLogStatus.SUCCESS);
    }

    private void saveLog(User user, ActivityAction action, String description, ActivityLogStatus status) {
        activityLogRepository.save(ActivityLog.builder()
                .user(user)
                .action(action)
                .logType(action.category())
                .status(status)
                .description(description)
                .ipAddress("127.0.0.1")
                .userAgent("StoreHub Mobile / 2.0")
                .build());
    }
}
