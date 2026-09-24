ALTER TABLE users ADD COLUMN IF NOT EXISTS facility_id UUID;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_users_facility'
    ) THEN
ALTER TABLE users
    ADD CONSTRAINT fk_users_facility
        FOREIGN KEY (facility_id)
            REFERENCES facilities(id);
END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_storage_units_facility_code
    ON storage_units(facility_id, unit_code);