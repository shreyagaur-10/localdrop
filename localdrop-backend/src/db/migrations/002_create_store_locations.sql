-- Migration 002: Store locations for multi-branch businesses (new table only)
CREATE TABLE IF NOT EXISTS store_locations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_name   VARCHAR(200) NOT NULL,
  address       TEXT,
  city          VARCHAR(100),
  state         VARCHAR(100),
  lat           NUMERIC(10, 7),
  lng           NUMERIC(10, 7),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_store_locations_business_id ON store_locations(business_id);
