-- =====================================================================
-- StoreHub - Khởi tạo cơ sở dữ liệu (gộp từ các migration V1..V30 cũ)
--
--   Phần 1: cấu trúc bảng + index (trạng thái cuối cùng).
--   Phần 2: dữ liệu mặc định (vai trò, quyền, phân quyền, cơ sở, loại kho, ngăn kho).
--
-- Việc căn chỉnh phân quyền cuối cùng (Admin chỉ xem giao dịch, không sửa danh mục/chính
-- sách/giá/báo cáo doanh thu) nằm ở R__align_role_permissions.sql để áp dụng cả cho
-- cơ sở dữ liệu đã tạo từ trước.
-- =====================================================================

-- ======================== PHẦN 1: CẤU TRÚC ========================
-- =========================================================
-- ROLES
-- =========================================================

CREATE TABLE IF NOT EXISTS roles
(
    id          UUID         NOT NULL,
    created_at  TIMESTAMP    NOT NULL,
    updated_at  TIMESTAMP    NOT NULL,
    name        VARCHAR(50)  NOT NULL,
    description VARCHAR(255),
    is_active   BOOLEAN      NOT NULL,

    CONSTRAINT pk_roles PRIMARY KEY (id),
    CONSTRAINT uc_roles_name UNIQUE (name)
);


-- =========================================================
-- PERMISSIONS
-- =========================================================

CREATE TABLE IF NOT EXISTS permissions
(
    id                UUID         NOT NULL,
    created_at        TIMESTAMP    NOT NULL,
    updated_at        TIMESTAMP    NOT NULL,
    name              VARCHAR(255) NOT NULL,
    permission_group  VARCHAR(255) NOT NULL,
    description       VARCHAR(255),
    is_active         BOOLEAN      NOT NULL,

    CONSTRAINT pk_permissions PRIMARY KEY (id),
    CONSTRAINT uc_permissions_name UNIQUE (name)
);


-- =========================================================
-- USERS
-- =========================================================

CREATE TABLE IF NOT EXISTS users
(
    id           UUID         NOT NULL,
    created_at   TIMESTAMP    NOT NULL,
    updated_at   TIMESTAMP    NOT NULL,
    username     VARCHAR(30)  NOT NULL,
    email        VARCHAR(255) NOT NULL,
    password     VARCHAR(255) NOT NULL,
    phone        VARCHAR(20)  NOT NULL,
    full_name    VARCHAR(30),
    is_active    BOOLEAN      NOT NULL,
    avatar       VARCHAR(255),
    assigned_by  UUID,
    assigned_at  TIMESTAMP,
    role_id      UUID,
    facility_id  UUID,

    CONSTRAINT pk_users PRIMARY KEY (id),
    CONSTRAINT uc_users_username UNIQUE (username),
    CONSTRAINT uc_users_email UNIQUE (email),

    CONSTRAINT fk_users_role
        FOREIGN KEY (role_id) REFERENCES roles(id),

    CONSTRAINT fk_users_assigned_by
        FOREIGN KEY (assigned_by) REFERENCES users(id)
);


-- =========================================================
-- REFRESH TOKENS
-- =========================================================

CREATE TABLE IF NOT EXISTS refresh_tokens
(
    id            UUID         NOT NULL,
    created_at    TIMESTAMP    NOT NULL,
    updated_at    TIMESTAMP    NOT NULL,
    user_id       UUID         NOT NULL,
    token         TEXT         NOT NULL,
    type          VARCHAR(255) NOT NULL,
    expired_at    TIMESTAMP    NOT NULL,
    last_used_at  TIMESTAMP    NOT NULL,
    revoked       BOOLEAN      NOT NULL,

    CONSTRAINT pk_refresh_tokens PRIMARY KEY (id),
    CONSTRAINT uc_refresh_tokens_token UNIQUE (token),

    CONSTRAINT fk_refresh_tokens_user
        FOREIGN KEY (user_id) REFERENCES users(id)
);


-- =========================================================
-- ROLE PERMISSIONS
-- =========================================================

CREATE TABLE IF NOT EXISTS role_permissions
(
    id             UUID         NOT NULL,
    created_at     TIMESTAMP    NOT NULL,
    updated_at     TIMESTAMP    NOT NULL,
    role_id        UUID         NOT NULL,
    permission_id  UUID         NOT NULL,
    is_active      BOOLEAN      NOT NULL,
    description    VARCHAR(255),

    CONSTRAINT pk_role_permissions PRIMARY KEY (id),
    CONSTRAINT uc_role_permissions_role_permission UNIQUE (role_id, permission_id),

    CONSTRAINT fk_role_permissions_role
        FOREIGN KEY (role_id) REFERENCES roles(id),

    CONSTRAINT fk_role_permissions_permission
        FOREIGN KEY (permission_id) REFERENCES permissions(id)
);


-- =========================================================
-- FACILITIES
-- =========================================================

CREATE TABLE IF NOT EXISTS facilities
(
    id                   UUID         NOT NULL,
    created_at           TIMESTAMP    NOT NULL,
    updated_at           TIMESTAMP    NOT NULL,
    name                 VARCHAR(150) NOT NULL,
    code                 VARCHAR(30)  NOT NULL,
    address              VARCHAR(255) NOT NULL,
    city                 VARCHAR(50),
    contact_phone        VARCHAR(20),
    email                VARCHAR(150),
    manager_id           UUID,
    status               VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    open_time            TIME         NOT NULL DEFAULT '08:00',
    close_time           TIME         NOT NULL DEFAULT '20:00',
    description          TEXT,
    air_conditioned_24h  BOOLEAN      NOT NULL DEFAULT FALSE,
    image_url            VARCHAR(500),
    images               TEXT,

    CONSTRAINT pk_facilities PRIMARY KEY (id),
    CONSTRAINT uc_facilities_code UNIQUE (code),

    CONSTRAINT fk_facilities_manager
        FOREIGN KEY (manager_id) REFERENCES users(id)
);

-- Idempotent: DB cũ có thể đã có ràng buộc này.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_users_facility' AND conrelid = 'users'::regclass
    ) THEN
        ALTER TABLE users
            ADD CONSTRAINT fk_users_facility
            FOREIGN KEY (facility_id) REFERENCES facilities(id);
    END IF;
END $$;


-- =========================================================
-- UNIT TYPES
-- =========================================================

CREATE TABLE IF NOT EXISTS unit_types
(
    id                    UUID             NOT NULL,
    created_at            TIMESTAMP        NOT NULL,
    updated_at            TIMESTAMP        NOT NULL,
    type_name             VARCHAR(100)     NOT NULL,
    dimensions            VARCHAR(50)      NOT NULL,
    area_sqm              DOUBLE PRECISION NOT NULL,
    base_price_per_month  NUMERIC(12,2)    NOT NULL,
    deposit_amount        NUMERIC(12,2)    NOT NULL,
    image_url             VARCHAR(500),

    CONSTRAINT pk_unit_types PRIMARY KEY (id)
);


-- =========================================================
-- WAITLISTS
-- =========================================================

CREATE TABLE IF NOT EXISTS waitlists
(
    id                 UUID                     NOT NULL,
    created_at         TIMESTAMP                NOT NULL,
    updated_at         TIMESTAMP                NOT NULL,
    customer_id        UUID                     NOT NULL,
    facility_id        UUID                     NOT NULL,
    unit_type_id       UUID                     NOT NULL,
    status             VARCHAR(20)              NOT NULL,
    notified_at        TIMESTAMP WITH TIME ZONE,
    offer_expires_at   TIMESTAMP WITH TIME ZONE,

    CONSTRAINT pk_waitlists PRIMARY KEY (id),

    CONSTRAINT fk_waitlists_customer
        FOREIGN KEY (customer_id) REFERENCES users(id),

    CONSTRAINT fk_waitlists_facility
        FOREIGN KEY (facility_id) REFERENCES facilities(id),

    CONSTRAINT fk_waitlists_unit_type
        FOREIGN KEY (unit_type_id) REFERENCES unit_types(id)
);

CREATE INDEX IF NOT EXISTS idx_waitlist_facility_unittype_status
    ON waitlists(facility_id, unit_type_id, status);


-- =========================================================
-- STORAGE UNITS
-- =========================================================

CREATE TABLE IF NOT EXISTS storage_units
(
    id             UUID        NOT NULL,
    created_at     TIMESTAMP   NOT NULL,
    updated_at     TIMESTAMP   NOT NULL,
    unit_code      VARCHAR(30) NOT NULL,
    floor_level    VARCHAR(50),
    status         VARCHAR(30) NOT NULL,
    facility_id    UUID        NOT NULL,
    unit_type_id   UUID        NOT NULL,

    CONSTRAINT pk_storage_units PRIMARY KEY (id),

    CONSTRAINT fk_storage_units_facility
        FOREIGN KEY (facility_id) REFERENCES facilities(id),

    CONSTRAINT fk_storage_units_unit_type
        FOREIGN KEY (unit_type_id) REFERENCES unit_types(id)
);


-- =========================================================
-- FACILITY POLICIES
-- =========================================================

CREATE TABLE IF NOT EXISTS facility_policies
(
    id                                   UUID             NOT NULL,
    created_at                           TIMESTAMP        NOT NULL,
    updated_at                           TIMESTAMP        NOT NULL,
    facility_id                          UUID             NOT NULL,
    deposit_percentage                   DOUBLE PRECISION NOT NULL,
    renewal_window_days                  INTEGER          NOT NULL DEFAULT 3,
    cancellation_full_refund_hours       INTEGER          NOT NULL DEFAULT 48,
    cancellation_partial_refund_hours    INTEGER          NOT NULL DEFAULT 24,
    cancellation_partial_refund_percent  DOUBLE PRECISION NOT NULL DEFAULT 50.0,
    return_notice_days                   INTEGER          NOT NULL DEFAULT 0,
    deposit_refund_sla_days              INTEGER          NOT NULL DEFAULT 5,
    daily_late_fee                       NUMERIC(12,2)    NOT NULL,
    overdue_grace_days                   INTEGER          NOT NULL DEFAULT 1,
    overdue_access_disable_days          INTEGER          NOT NULL DEFAULT 3,
    overdue_sealing_days                 INTEGER          NOT NULL DEFAULT 7,
    minimum_rental_months                INTEGER          NOT NULL DEFAULT 1,
    max_advance_reservation_days         INTEGER          NOT NULL DEFAULT 14,
    management_fee_per_month             NUMERIC(12,0)    NOT NULL DEFAULT 50000,
    long_term_discount_min_months        INTEGER          NOT NULL DEFAULT 0,
    long_term_discount_percent           DOUBLE PRECISION NOT NULL DEFAULT 0,
    prohibited_items                     TEXT,
    terms_and_conditions                 TEXT,
    terms_version                        VARCHAR(30)      DEFAULT 'v2026.1',

    CONSTRAINT pk_facility_policies PRIMARY KEY (id),
    CONSTRAINT uc_facility_policies_facility UNIQUE (facility_id),
    CONSTRAINT fk_facility_policies_facility FOREIGN KEY (facility_id) REFERENCES facilities(id)
);


-- =========================================================
-- BOOKINGS
-- =========================================================

CREATE TABLE IF NOT EXISTS bookings
(
    id                           UUID          NOT NULL,
    created_at                   TIMESTAMP     NOT NULL,
    updated_at                   TIMESTAMP     NOT NULL,
    booking_code                 VARCHAR(30)   NOT NULL,
    customer_id                  UUID          NOT NULL,
    storage_unit_id              UUID          NOT NULL,
    start_date                   DATE          NOT NULL,
    scheduled_check_in_time      TIMESTAMP,
    end_date                     DATE          NOT NULL,
    rental_months                INTEGER       NOT NULL,
    total_rental_fee             NUMERIC(12,2) NOT NULL,
    quoted_deposit_amount        NUMERIC(12,2),
    quoted_management_fee        NUMERIC(12,2),
    deposit_paid                 NUMERIC(12,2) NOT NULL,
    status                       VARCHAR(30)   NOT NULL,
    access_code                  VARCHAR(20),
    access_pin                   VARCHAR(100),
    pin_failed_attempts          INTEGER       NOT NULL DEFAULT 0,
    pin_locked_until             TIMESTAMP,
    pin_updated_at               TIMESTAMP,
    handed_over_by_staff_id      UUID,
    handover_time                TIMESTAMP,
    return_time                  TIMESTAMP,
    scheduled_return_time        TIMESTAMP,
    assigned_check_in_staff_id   UUID,
    assigned_check_out_staff_id  UUID,
    expires_at                   TIMESTAMP,
    pending_extra_months         INTEGER,
    pending_extension_fee        NUMERIC(12,2),
    unit_locked                  BOOLEAN       NOT NULL DEFAULT TRUE,
    unit_assignment_confirmed    BOOLEAN       NOT NULL DEFAULT FALSE,
    overdue_detected_at          TIMESTAMP,
    overdue_fee_accrued          NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    access_disabled_at           TIMESTAMP,
    sealing_pending_at           TIMESTAMP,
    sealing_approved_at          TIMESTAMP,
    refund_bank_code             VARCHAR(50),
    refund_account_number        VARCHAR(50),
    refund_account_name          VARCHAR(100),
    prohibited_items_accepted    BOOLEAN       NOT NULL DEFAULT FALSE,
    terms_accepted               BOOLEAN       NOT NULL DEFAULT FALSE,
    terms_accepted_at            TIMESTAMP,
    terms_version                VARCHAR(30),

    CONSTRAINT pk_bookings PRIMARY KEY (id),
    CONSTRAINT uc_bookings_booking_code UNIQUE (booking_code),
    CONSTRAINT fk_bookings_customer FOREIGN KEY (customer_id) REFERENCES users(id),
    CONSTRAINT fk_bookings_storage_unit FOREIGN KEY (storage_unit_id) REFERENCES storage_units(id),
    CONSTRAINT fk_bookings_staff FOREIGN KEY (handed_over_by_staff_id) REFERENCES users(id),
    CONSTRAINT fk_bookings_assigned_check_in_staff FOREIGN KEY (assigned_check_in_staff_id) REFERENCES users(id),
    CONSTRAINT fk_bookings_assigned_check_out_staff FOREIGN KEY (assigned_check_out_staff_id) REFERENCES users(id)
);


-- =========================================================
-- PAYMENTS
-- =========================================================

CREATE TABLE IF NOT EXISTS payments
(
    id                      UUID          NOT NULL,
    created_at              TIMESTAMP     NOT NULL,
    updated_at              TIMESTAMP     NOT NULL,
    transaction_id          VARCHAR(60)   NOT NULL,
    booking_id              UUID          NOT NULL,
    amount                  NUMERIC(12,2) NOT NULL,
    payment_type            VARCHAR(30)   NOT NULL,
    status                  VARCHAR(30)   NOT NULL,
    payment_method          VARCHAR(50),
    payment_time            TIMESTAMP     NOT NULL,
    note                    VARCHAR(100),
    fine_days               INTEGER,
    gateway_create_date     VARCHAR(14),
    gateway_transaction_no  VARCHAR(20),
    gateway_amount          NUMERIC(12,2),
    last_gateway_query_at   TIMESTAMP,
    voided_at               TIMESTAMP,

    CONSTRAINT pk_payments PRIMARY KEY (id),
    CONSTRAINT uc_payments_transaction_id UNIQUE (transaction_id),
    CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id) REFERENCES bookings(id)
);


-- =========================================================
-- ACTIVITY_LOGS
-- =========================================================

CREATE TABLE IF NOT EXISTS activity_logs
(
    id                UUID         NOT NULL,
    created_at        TIMESTAMP    NOT NULL,
    updated_at        TIMESTAMP    NOT NULL,
    user_id           UUID,
    log_type          VARCHAR(20)  NOT NULL,
    action            VARCHAR(100) NOT NULL,
    email_attempted   VARCHAR(150),
    resource_type     VARCHAR(100),
    resource_id       UUID,
    description       VARCHAR(500),
    old_value         TEXT,
    new_value         TEXT,
    status            VARCHAR(20)  NOT NULL,
    ip_address        VARCHAR(45),
    user_agent        VARCHAR(255),

    CONSTRAINT pk_activity_logs PRIMARY KEY (id),
    CONSTRAINT fk_activity_logs_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_log_type ON activity_logs(log_type);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at);


-- =========================================================
-- HANDOVER RECORDS
-- =========================================================

CREATE TABLE IF NOT EXISTS handover_records
(
    id             UUID          NOT NULL,
    created_at     TIMESTAMP     NOT NULL,
    updated_at     TIMESTAMP     NOT NULL,
    booking_id     UUID          NOT NULL,
    staff_id       UUID          NOT NULL,
    record_type    VARCHAR(30)   NOT NULL,
    unit_condition TEXT,
    notes          TEXT,
    recorded_at    TIMESTAMP     NOT NULL,
    damage_fee     NUMERIC(12,2) DEFAULT 0,
    damage_reason  VARCHAR(255),
    photos         TEXT,

    CONSTRAINT pk_handover_records PRIMARY KEY (id),
    CONSTRAINT fk_handover_records_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
    CONSTRAINT fk_handover_records_staff FOREIGN KEY (staff_id) REFERENCES users(id)
);


-- =========================================================
-- SUPPORT_TICKETS
-- =========================================================

CREATE TABLE IF NOT EXISTS support_tickets
(
    id                  UUID         NOT NULL,
    ticket_code         VARCHAR(50)  NOT NULL,
    user_id             UUID         NOT NULL,
    booking_id          UUID,
    category            VARCHAR(50)  NOT NULL,
    title               VARCHAR(255) NOT NULL,
    description         TEXT         NOT NULL,
    status              VARCHAR(30)  NOT NULL DEFAULT 'OPEN',
    priority            VARCHAR(20)  NOT NULL DEFAULT 'MEDIUM',
    assigned_staff_id   UUID,
    resolution_note     TEXT,
    photos              TEXT,
    created_at          TIMESTAMP    NOT NULL,
    updated_at          TIMESTAMP    NOT NULL,

    CONSTRAINT pk_support_tickets PRIMARY KEY (id),
    CONSTRAINT uc_support_tickets_code UNIQUE (ticket_code),
    CONSTRAINT fk_support_tickets_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_support_tickets_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
    CONSTRAINT fk_support_tickets_staff FOREIGN KEY (assigned_staff_id) REFERENCES users(id)
);


-- =========================================================
-- REFUND_REQUESTS
-- =========================================================

CREATE TABLE IF NOT EXISTS refund_requests
(
    id                         UUID           NOT NULL,
    created_at                 TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                 TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    booking_id                 UUID           NOT NULL,
    original_payment_id        UUID           NOT NULL,
    refund_payment_id          UUID           NOT NULL,
    request_id                 VARCHAR(32)    NOT NULL,
    amount                     NUMERIC(12,2)  NOT NULL,
    deposit_amount             NUMERIC(12,2)  NOT NULL,
    rental_amount              NUMERIC(12,2)  NOT NULL,
    status                     VARCHAR(30)    NOT NULL,
    gateway_response_code      VARCHAR(10),
    gateway_transaction_status VARCHAR(10),
    updated_status_at          TIMESTAMP,
    due_at                     TIMESTAMP      NOT NULL,
    completed_at               TIMESTAMP,
    damage_deduction           NUMERIC(12,2)  DEFAULT 0,
    bank_code                  VARCHAR(50),
    bank_account_number        VARCHAR(50),
    bank_account_name          VARCHAR(100),
    transfer_reference         VARCHAR(100),

    CONSTRAINT pk_refund_requests PRIMARY KEY (id),
    CONSTRAINT uc_refund_requests_refund_payment UNIQUE (refund_payment_id),
    CONSTRAINT uc_refund_requests_request_id UNIQUE (request_id),
    CONSTRAINT fk_refund_requests_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
    CONSTRAINT fk_refund_requests_original_payment FOREIGN KEY (original_payment_id) REFERENCES payments(id),
    CONSTRAINT fk_refund_requests_refund_payment FOREIGN KEY (refund_payment_id) REFERENCES payments(id)
);

CREATE INDEX IF NOT EXISTS idx_refund_requests_status ON refund_requests(status);


-- =========================================================
-- GATE_PASSES
-- =========================================================

CREATE TABLE IF NOT EXISTS gate_passes
(
    id           UUID                        NOT NULL,
    created_at   TIMESTAMP                   NOT NULL,
    updated_at   TIMESTAMP                   NOT NULL,
    booking_id   UUID                        NOT NULL,
    facility_id  UUID                        NOT NULL,
    token_hash   VARCHAR(64)                 NOT NULL,
    expires_at   TIMESTAMP WITH TIME ZONE    NOT NULL,
    used_at      TIMESTAMP WITH TIME ZONE,
    revoked_at   TIMESTAMP WITH TIME ZONE,

    CONSTRAINT pk_gate_passes PRIMARY KEY (id),
    CONSTRAINT uc_gate_passes_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_gate_passes_booking FOREIGN KEY (booking_id) REFERENCES bookings(id),
    CONSTRAINT fk_gate_passes_facility FOREIGN KEY (facility_id) REFERENCES facilities(id)
);

CREATE INDEX IF NOT EXISTS idx_gate_passes_booking ON gate_passes(booking_id);

-- Index bổ sung (trước đây nằm rải rác ở V13, V15, V19)
CREATE INDEX IF NOT EXISTS idx_bookings_check_in_staff ON bookings(assigned_check_in_staff_id);
CREATE INDEX IF NOT EXISTS idx_bookings_check_out_staff ON bookings(assigned_check_out_staff_id);
CREATE INDEX IF NOT EXISTS idx_payments_charge_reconciliation
    ON payments(status, payment_time, last_gateway_query_at)
    WHERE gateway_create_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_refund_requests_booking ON refund_requests(booking_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_refund_requests_original_payment ON refund_requests(original_payment_id);
CREATE INDEX IF NOT EXISTS idx_refund_requests_completed_at
    ON refund_requests(completed_at) WHERE status = 'COMPLETED';

-- ======================== PHẦN 2: DỮ LIỆU MẶC ĐỊNH ========================

-- ---- Vai trò ----
INSERT INTO roles
(
    id,
    created_at,
    updated_at,
    name,
    description,
    is_active
)
VALUES
    (
        '11111111-1111-1111-1111-111111111111',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        'ADMIN',
        'System administrator',
        TRUE
    ),
    (
        '22222222-2222-2222-2222-222222222222',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        'FACILITY_MANAGER',
        'Facility manager',
        TRUE
    ),
    (
        '33333333-3333-3333-3333-333333333333',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        'BUSINESS_MANAGER',
        'Business manager',
        TRUE
    ),
    (
        '44444444-4444-4444-4444-444444444444',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        'STAFF',
        'Store staff',
        TRUE
    ),
    (
        '55555555-5555-5555-5555-555555555555',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        'CUSTOMER',
        'Store customer',
        TRUE
    )
    ON CONFLICT (id) DO NOTHING;

-- ---- Quyền ----
INSERT INTO permissions (id, created_at, updated_at, name, permission_group, description, is_active)
VALUES
-- USER
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'USER_VIEW', 'USER', 'View users', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'USER_CREATE', 'USER', 'Create users', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'USER_UPDATE', 'USER', 'Update users', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'USER_DELETE', 'USER', 'Delete users', TRUE),

-- ROLE
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ROLE_VIEW', 'ROLE', 'View roles', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ROLE_CREATE', 'ROLE', 'Create roles', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ROLE_UPDATE', 'ROLE', 'Update roles', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ROLE_DELETE', 'ROLE', 'Delete roles', TRUE),

-- PERMISSION
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'PERMISSION_VIEW', 'PERMISSION', 'View permissions', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'PERMISSION_CREATE', 'PERMISSION', 'Create permissions', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'PERMISSION_UPDATE', 'PERMISSION', 'Update permissions', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'PERMISSION_DELETE', 'PERMISSION', 'Delete permissions', TRUE),

-- ROLE_PERMISSION
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ROLE_PERMISSION_VIEW', 'ROLE_PERMISSION', 'View role-permission assignments', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ROLE_PERMISSION_ASSIGN', 'ROLE_PERMISSION', 'Assign a permission to a role', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ROLE_PERMISSION_REVOKE', 'ROLE_PERMISSION', 'Revoke a permission from a role', TRUE),

-- FACILITY
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'FACILITY_VIEW', 'FACILITY', 'View facilities', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'FACILITY_CREATE', 'FACILITY', 'Create facilities', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'FACILITY_UPDATE', 'FACILITY', 'Update facilities', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'FACILITY_DELETE', 'FACILITY', 'Delete facilities', TRUE),

-- UNIT_TYPE
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'UNIT_TYPE_VIEW', 'UNIT_TYPE', 'View unit types', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'UNIT_TYPE_CREATE', 'UNIT_TYPE', 'Create unit types', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'UNIT_TYPE_UPDATE', 'UNIT_TYPE', 'Update unit types', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'UNIT_TYPE_DELETE', 'UNIT_TYPE', 'Delete unit types', TRUE),

-- STORAGE_UNIT
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'STORAGE_UNIT_VIEW', 'STORAGE_UNIT', 'View storage units', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'STORAGE_UNIT_CREATE', 'STORAGE_UNIT', 'Create storage units', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'STORAGE_UNIT_UPDATE', 'STORAGE_UNIT', 'Update storage units', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'STORAGE_UNIT_DELETE', 'STORAGE_UNIT', 'Delete storage units', TRUE),

-- POLICY (facility policy)
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'POLICY_VIEW', 'POLICY', 'View facility policies', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'POLICY_CREATE', 'POLICY', 'Create facility policies', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'POLICY_UPDATE', 'POLICY', 'Update facility policies', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'POLICY_DELETE', 'POLICY', 'Delete facility policies', TRUE),

-- BOOKING (reservation)
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'BOOKING_VIEW', 'BOOKING', 'View bookings', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'BOOKING_CREATE', 'BOOKING', 'Create bookings', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'BOOKING_UPDATE', 'BOOKING', 'Update bookings', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'BOOKING_CANCEL', 'BOOKING', 'Cancel bookings', TRUE),

-- CONTRACT (rental contract)
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CONTRACT_VIEW', 'CONTRACT', 'View rental contracts', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CONTRACT_CREATE', 'CONTRACT', 'Create rental contracts', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'CONTRACT_UPDATE', 'CONTRACT', 'Update rental contract status', TRUE),

-- HANDOVER (check-in / checkout records)
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'HANDOVER_VIEW', 'HANDOVER', 'View handover/checkout records', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'HANDOVER_CREATE', 'HANDOVER', 'Complete check-in handover or checkout inspection', TRUE),

-- ACCESS_CREDENTIAL
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ACCESS_CREDENTIAL_VIEW', 'ACCESS_CREDENTIAL', 'View a unit''s access credential', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ACCESS_CREDENTIAL_UPDATE', 'ACCESS_CREDENTIAL', 'Regenerate an access PIN/code', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ACCESS_CREDENTIAL_REVOKE', 'ACCESS_CREDENTIAL', 'Revoke an access credential', TRUE),

-- PAYMENT
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'PAYMENT_VIEW', 'PAYMENT', 'View payments', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'PAYMENT_CREATE', 'PAYMENT', 'Create payments', TRUE),

-- RENEWAL
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'RENEWAL_VIEW', 'RENEWAL', 'View renewal requests', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'RENEWAL_CREATE', 'RENEWAL', 'Create/pay a renewal request', TRUE),

-- OVERDUE
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OVERDUE_VIEW', 'OVERDUE', 'View overdue cases', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'OVERDUE_PROCESS', 'OVERDUE', 'Approve overdue sealing/processing', TRUE),

-- REFUND (deposit refund)
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'REFUND_VIEW', 'REFUND', 'View deposit refund requests', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'REFUND_APPROVE', 'REFUND', 'Approve a deposit refund', TRUE),

-- DISCOUNT
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'DISCOUNT_VIEW', 'DISCOUNT', 'View discounts', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'DISCOUNT_CREATE', 'DISCOUNT', 'Create discounts', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'DISCOUNT_UPDATE', 'DISCOUNT', 'Update discounts', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'DISCOUNT_DELETE', 'DISCOUNT', 'Delete discounts', TRUE),

-- SUPPORT
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SUPPORT_VIEW', 'SUPPORT', 'View support tickets', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SUPPORT_CREATE', 'SUPPORT', 'Create support tickets', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'SUPPORT_UPDATE', 'SUPPORT', 'Update support tickets', TRUE),

-- STAFF_ASSIGNMENT
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'STAFF_ASSIGNMENT_VIEW', 'STAFF_ASSIGNMENT', 'View staff assignments', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'STAFF_ASSIGNMENT_CREATE', 'STAFF_ASSIGNMENT', 'Assign staff to a facility', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'STAFF_ASSIGNMENT_DELETE', 'STAFF_ASSIGNMENT', 'Remove a staff assignment', TRUE),

-- REPORT
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'REPORT_VIEW', 'REPORT', 'View business reports', TRUE),

-- ACTIVITY_LOG / LOGIN_HISTORY
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ACTIVITY_LOG_VIEW', 'ACTIVITY_LOG', 'View activity/audit logs', TRUE),
(gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'LOGIN_HISTORY_VIEW', 'LOGIN_HISTORY', 'View login history', TRUE)

ON CONFLICT (name) DO NOTHING;

-- ---- Phân quyền theo vai trò ----
-- ADMIN: full access — không đổi, WHERE is_active = TRUE tự động cuốn theo mọi permission mới
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'ADMIN full system access'
FROM roles r, permissions p
WHERE r.name = 'ADMIN' AND p.is_active = TRUE
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- BUSINESS OPERATIONS MANAGER: thêm UNIT_TYPE, DISCOUNT (quản lý giá/khuyến mãi toàn hệ thống)
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Business operations management permission'
FROM roles r, permissions p
WHERE r.name = 'BUSINESS_MANAGER'
  AND p.permission_group IN
      ('FACILITY','UNIT_TYPE','STORAGE_UNIT','BOOKING','PAYMENT','REPORT','POLICY','DISCOUNT')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- FACILITY MANAGER: thêm UNIT_TYPE, CONTRACT, HANDOVER, ACCESS_CREDENTIAL, RENEWAL, OVERDUE, REFUND, STAFF_ASSIGNMENT
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Facility manager permission'
FROM roles r, permissions p
WHERE r.name = 'FACILITY_MANAGER'
  AND p.permission_group IN
      ('FACILITY','UNIT_TYPE','STORAGE_UNIT','BOOKING','CONTRACT','HANDOVER',
       'ACCESS_CREDENTIAL','PAYMENT','RENEWAL','OVERDUE','REFUND','SUPPORT',
       'STAFF_ASSIGNMENT','REPORT')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Facility Manager chỉ được XEM policy, không được sửa (POLICY_CREATE/UPDATE/DELETE thuộc Business Ops Manager)
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Facility manager permission'
FROM roles r, permissions p
WHERE r.name = 'FACILITY_MANAGER'
  AND p.name = 'POLICY_VIEW'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- FACILITY STAFF: thêm HANDOVER, ACCESS_CREDENTIAL_VIEW, CONTRACT_VIEW
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Facility staff permission'
FROM roles r, permissions p
WHERE r.name = 'STAFF'
  AND p.name IN
      ('FACILITY_VIEW','STORAGE_UNIT_VIEW','STORAGE_UNIT_UPDATE',
       'BOOKING_VIEW','BOOKING_UPDATE','CONTRACT_VIEW',
       'HANDOVER_VIEW','HANDOVER_CREATE',
       'ACCESS_CREDENTIAL_VIEW',
       'PAYMENT_VIEW','SUPPORT_VIEW','SUPPORT_UPDATE')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- CUSTOMER: thêm UNIT_TYPE_VIEW, CONTRACT_VIEW, ACCESS_CREDENTIAL_VIEW, RENEWAL
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Customer permission'
FROM roles r, permissions p
WHERE r.name = 'CUSTOMER'
  AND p.name IN
      ('FACILITY_VIEW','UNIT_TYPE_VIEW','STORAGE_UNIT_VIEW',
       'BOOKING_VIEW','BOOKING_CREATE','BOOKING_CANCEL',
       'CONTRACT_VIEW','ACCESS_CREDENTIAL_VIEW',
       'RENEWAL_VIEW','RENEWAL_CREATE',
       'PAYMENT_VIEW','PAYMENT_CREATE',
       'SUPPORT_VIEW','SUPPORT_CREATE')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- BUSINESS_MANAGER: Dashboard read access (from V27)
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Dashboard read access'
FROM roles r CROSS JOIN permissions p
WHERE r.name = 'BUSINESS_MANAGER'
  AND p.name IN ('USER_VIEW', 'ROLE_VIEW', 'PERMISSION_VIEW', 'ROLE_PERMISSION_VIEW')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- FACILITY_MANAGER: Read role configuration (from V27)
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Read role configuration'
FROM roles r CROSS JOIN permissions p
WHERE r.name = 'FACILITY_MANAGER'
  AND p.name IN ('ROLE_VIEW', 'PERMISSION_VIEW', 'ROLE_PERMISSION_VIEW')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- STAFF & CUSTOMER: Operational access permissions (from V29)
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Operational access permission'
FROM roles r, permissions p
WHERE (r.name = 'STAFF' AND p.name = 'ACCESS_CREDENTIAL_UPDATE')
   OR (r.name = 'CUSTOMER' AND p.name IN ('ACCESS_CREDENTIAL_UPDATE', 'CONTRACT_UPDATE'))
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- ---- Cơ sở và chính sách mặc định ----
-- Idempotent: bỏ qua cơ sở đã tồn tại (DB cũ); chỉ cơ sở mới chèn mới được gán policy mặc định.
WITH new_facilities AS (
INSERT INTO facilities (
    id, name, code, address, city, contact_phone, email, status, open_time, close_time,
    air_conditioned_24h, image_url, images, created_at, updated_at
)
VALUES
    (
        gen_random_uuid(), 'StoreHub District 1', 'HCM-D1', '123 Nguyen Hue, Ben Nghe Ward', 'Ho Chi Minh City',
        '0901234567', 'storehubdistrict1@gmail.com', 'ACTIVE', '08:00:00', '20:00:00',
        TRUE, 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    ),
    (
        gen_random_uuid(), 'StoreHub District 7', 'HCM-D7', '456 Nguyen Huu Tho, Tan Hung Ward', 'Ho Chi Minh City',
        '0902345678', 'storehubdistrict7@gmail.com', 'ACTIVE', '08:00:00', '20:00:00',
        FALSE, 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    ),
    (
        gen_random_uuid(), 'StoreHub Thu Duc', 'HCM-TD', '789 Vo Van Ngan, Linh Chieu Ward', 'Ho Chi Minh City',
        '0903456789', 'storehubthuduc@gmail.com', 'ACTIVE', '08:00:00', '20:00:00',
        FALSE, 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    )
ON CONFLICT DO NOTHING
RETURNING id
)
INSERT INTO facility_policies (
    id, created_at, updated_at, facility_id, deposit_percentage,
    renewal_window_days,
    cancellation_full_refund_hours, cancellation_partial_refund_hours, cancellation_partial_refund_percent,
    return_notice_days, deposit_refund_sla_days,
    daily_late_fee, overdue_grace_days, overdue_access_disable_days, overdue_sealing_days,
    minimum_rental_months, max_advance_reservation_days,
    management_fee_per_month, long_term_discount_min_months, long_term_discount_percent,
    prohibited_items, terms_and_conditions, terms_version
)
SELECT
    gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, id, 20.0,
    3,
    48, 24, 50.0,
    0, 5,
    50000.00, 1, 3, 7,
    1, 14,
    50000.00, 0, 0.0,
    'Chất dễ cháy nổ, bình gas, xăng dầu; Ma túy, chất kích thích, hóa chất độc hại; Động vật sống, thực phẩm tươi sống dễ thối rữa; Vũ khí, đạn dược, hàng cấm, pháo hoa; Hàng hóa có mùi nồng nặc gây ảnh hưởng kho xung quanh',
    E'1. Khách hàng cam kết tuân thủ quy chế vận hành và an toàn PCCC tại cơ sở lưu kho StoreHub.\n2. Tuyệt đối không lưu trữ hàng hóa thuộc danh mục cấm theo quy định của pháp luật và nội quy kho.\n3. Khách hàng chịu hoàn toàn trách nhiệm pháp lý và bồi thường nếu hàng hóa gây thiệt hại, cháy nổ hoặc vi phạm pháp luật.\n4. Thanh toán đúng hạn theo thỏa thuận thuê kho và phối hợp thực hiện bàn giao, kiểm tra kho khi có yêu cầu.',
    'v2026.1'
FROM new_facilities;

-- ---- Loại kho ----
INSERT INTO unit_types (
    id,
    created_at,
    updated_at,
    type_name,
    dimensions,
    area_sqm,
    base_price_per_month,
    deposit_amount,
    image_url
)
SELECT
    gen_random_uuid(),
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    seed.type_name,
    seed.dimensions,
    seed.area_sqm,
    seed.base_price_per_month,
    seed.deposit_amount,
    seed.image_url
FROM (
         VALUES
             (
                 'Small',
                 '1m x 1m x 1m',
                 1.0::DOUBLE PRECISION,
                 500000.00::NUMERIC,
                 500000.00::NUMERIC,
                 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?auto=format&fit=crop&w=800&q=80'
             ),
             (
                 'Medium',
                 '2m x 2m x 2m',
                 4.0::DOUBLE PRECISION,
                 1200000.00::NUMERIC,
                 1200000.00::NUMERIC,
                 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?auto=format&fit=crop&w=800&q=80'
             ),
             (
                 'Large',
                 '3m x 3m x 3m',
                 9.0::DOUBLE PRECISION,
                 2500000.00::NUMERIC,
                 2500000.00::NUMERIC,
                 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?auto=format&fit=crop&w=800&q=80'
             )
     ) AS seed (
                type_name,
                dimensions,
                area_sqm,
                base_price_per_month,
                deposit_amount,
                image_url
    )
WHERE NOT EXISTS (
    SELECT 1
    FROM unit_types existing
    WHERE existing.type_name = seed.type_name
      AND existing.dimensions = seed.dimensions
);

-- ---- Ngăn kho ----
-- Seed available storage units for all facilities and unit types
INSERT INTO storage_units (
    id, created_at, updated_at, unit_code, floor_level, status, facility_id, unit_type_id
)
SELECT
    gen_random_uuid(),
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    u.unit_code,
    u.floor_level,
    'AVAILABLE',
    f.id,
    ut.id
FROM facilities f
CROSS JOIN unit_types ut
CROSS JOIN (
    VALUES 
        ('S-101', 'Floor 1', 'Small'),
        ('S-102', 'Floor 1', 'Small'),
        ('M-201', 'Floor 2', 'Medium'),
        ('M-202', 'Floor 2', 'Medium'),
        ('L-301', 'Floor 3', 'Large'),
        ('L-302', 'Floor 3', 'Large')
) AS u(unit_code, floor_level, type_name)
WHERE ut.type_name = u.type_name
AND NOT EXISTS (
    SELECT 1 FROM storage_units su
    WHERE su.facility_id = f.id AND su.unit_code = u.unit_code
);
