-- Migration 001: Add profile_photo_url to profile tables (additive only)
ALTER TABLE creator_profiles
  ADD COLUMN IF NOT EXISTS profile_photo_url VARCHAR(500);

ALTER TABLE business_profiles
  ADD COLUMN IF NOT EXISTS profile_photo_url VARCHAR(500);
