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
