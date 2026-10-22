-- Never guess which of two physical units with the same code should be kept:
-- either row may already be referenced by a booking or handover record.
DO $$
DECLARE
    duplicate_code RECORD;
BEGIN
    SELECT facility_id, unit_code, COUNT(*) AS copies
    INTO duplicate_code
    FROM storage_units
    GROUP BY facility_id, unit_code
    HAVING COUNT(*) > 1
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION
            'Duplicate storage unit code % in facility % (% rows). Resolve duplicate physical units before retrying V2.',
            duplicate_code.unit_code, duplicate_code.facility_id, duplicate_code.copies
            USING HINT = 'SELECT facility_id, unit_code, count(*) FROM storage_units GROUP BY facility_id, unit_code HAVING count(*) > 1;';
    END IF;
END $$;

ALTER TABLE storage_units
    ADD CONSTRAINT uq_storage_units_facility_code UNIQUE (facility_id, unit_code);
