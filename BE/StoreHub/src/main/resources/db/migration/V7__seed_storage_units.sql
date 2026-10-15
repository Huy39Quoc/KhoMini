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
