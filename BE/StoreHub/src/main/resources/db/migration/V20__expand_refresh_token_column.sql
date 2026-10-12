-- Signed refresh/reset JWTs can exceed the original VARCHAR(255) limit.
-- Keep the existing unique constraint so token lookup remains unambiguous.
ALTER TABLE refresh_tokens ALTER COLUMN token TYPE TEXT;
