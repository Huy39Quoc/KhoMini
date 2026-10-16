-- Unknown amenities must not be advertised as present until confirmed by an admin.
ALTER TABLE facilities ADD COLUMN IF NOT EXISTS air_conditioned_24h BOOLEAN NOT NULL DEFAULT FALSE;
