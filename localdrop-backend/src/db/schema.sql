-- ============================================================
-- LocalDrop — PostgreSQL Schema
-- Run with: psql -U postgres -d localdrop -f schema.sql
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────
-- 1. USERS (creators, businesses, admins)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role          VARCHAR(20)  NOT NULL CHECK (role IN ('creator', 'business', 'admin')),
  is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
  is_verified   BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role  ON users(role);

-- ─────────────────────────────────────────────────────────
-- 2. CREATOR PROFILES
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS creator_profiles (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          VARCHAR(150) NOT NULL,
  niche         VARCHAR(150),
  avatar_url    TEXT,
  profile_photo_url VARCHAR(500),
  bio           TEXT,
  city          VARCHAR(100),
  state         VARCHAR(100),
  lat           NUMERIC(10, 7),
  lng           NUMERIC(10, 7),
  -- Payout details
  payout_method VARCHAR(20) CHECK (payout_method IN ('bank', 'upi')),
  bank_account  VARCHAR(50),
  bank_ifsc     VARCHAR(20),
  upi_id        VARCHAR(100),
  -- Stats (denormalized for speed)
  total_earnings  NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_paid      NUMERIC(12, 2) NOT NULL DEFAULT 0,
  pending_payout  NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_creator_profiles_user_id ON creator_profiles(user_id);

-- ─────────────────────────────────────────────────────────
-- 2B. AUDIENCE CLUSTERS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audience_clusters (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  area_name     VARCHAR(150) NOT NULL,
  lat           NUMERIC(10, 7) NOT NULL,
  lng           NUMERIC(10, 7) NOT NULL,
  weight_pct    INTEGER NOT NULL CHECK (weight_pct >= 0 AND weight_pct <= 100),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audience_clusters_creator_id ON audience_clusters(creator_id);

-- ─────────────────────────────────────────────────────────
-- 3. BUSINESS PROFILES
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS business_profiles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  business_name   VARCHAR(200) NOT NULL,
  business_type   VARCHAR(100),
  description     TEXT,
  logo_url        TEXT,
  profile_photo_url VARCHAR(500),
  cover_url       TEXT,
  phone           VARCHAR(20),
  email           VARCHAR(255),
  address         TEXT,
  city            VARCHAR(100),
  state           VARCHAR(100),
  lat             NUMERIC(10, 7),
  lng             NUMERIC(10, 7),
  social_instagram VARCHAR(200),
  social_facebook  VARCHAR(200),
  social_whatsapp  VARCHAR(20),
  -- Payout details
  payout_method   VARCHAR(20) CHECK (payout_method IN ('bank', 'upi')),
  bank_account    VARCHAR(50),
  bank_ifsc       VARCHAR(20),
  upi_id          VARCHAR(100),
  is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_business_profiles_user_id ON business_profiles(user_id);

-- ─────────────────────────────────────────────────────────
-- 3B. STORE LOCATIONS (multi-branch businesses)
-- ─────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────
-- 4. CAMPAIGNS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS campaigns (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            VARCHAR(300) NOT NULL,
  description     TEXT,
  campaign_type   VARCHAR(50) NOT NULL,   -- 'discount', 'bogo', 'freebie', 'cashback'
  offer_details   TEXT NOT NULL,          -- "Flat 20% Off on All Orders"
  image_url       TEXT,
  -- Commission & Budget
  commission_type VARCHAR(20) NOT NULL CHECK (commission_type IN ('fixed', 'percentage')),
  commission_value NUMERIC(10, 2) NOT NULL,   -- ₹20 fixed OR 10% of bill
  total_budget    NUMERIC(12, 2) NOT NULL,
  spent_budget    NUMERIC(12, 2) NOT NULL DEFAULT 0,
  -- Geo
  lat             NUMERIC(10, 7) NOT NULL,
  lng             NUMERIC(10, 7) NOT NULL,
  radius_km       NUMERIC(6, 2)  NOT NULL DEFAULT 5,
  -- Validity
  valid_from      DATE NOT NULL,
  valid_till      DATE NOT NULL,
  -- State
  status          VARCHAR(20) NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft', 'active', 'paused', 'ended', 'cancelled')),
  -- Stats (denormalized)
  total_views       INTEGER NOT NULL DEFAULT 0,
  total_claims      INTEGER NOT NULL DEFAULT 0,
  total_redemptions INTEGER NOT NULL DEFAULT 0,
  total_revenue     NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_campaigns_business_id ON campaigns(business_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status      ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_lat_lng     ON campaigns(lat, lng);
CREATE INDEX IF NOT EXISTS idx_campaigns_valid_till  ON campaigns(valid_till);

-- ─────────────────────────────────────────────────────────
-- 5. CAMPAIGN CREATORS (creator joins campaign)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS campaign_creators (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  creator_id  UUID NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (campaign_id, creator_id)
);

CREATE INDEX IF NOT EXISTS idx_cc_campaign_id ON campaign_creators(campaign_id);
CREATE INDEX IF NOT EXISTS idx_cc_creator_id  ON campaign_creators(creator_id);

-- ─────────────────────────────────────────────────────────
-- 6. QR CODES (one unique QR per creator per campaign)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS qr_codes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  creator_id  UUID NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  -- The short public URL / identifier embedded in QR
  qr_token    VARCHAR(64) UNIQUE NOT NULL,
  qr_data_url TEXT,          -- base64 PNG (cached, regenerated on demand)
  qr_link     TEXT NOT NULL, -- https://localdrop.com/c/<qr_token>
  -- Stats
  scan_count  INTEGER NOT NULL DEFAULT 0,
  claim_count INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (campaign_id, creator_id)
);

CREATE INDEX IF NOT EXISTS idx_qr_codes_qr_token    ON qr_codes(qr_token);
CREATE INDEX IF NOT EXISTS idx_qr_codes_campaign_id ON qr_codes(campaign_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_creator_id  ON qr_codes(creator_id);

-- ─────────────────────────────────────────────────────────
-- 7. REDEMPTIONS (customer claim → business confirm)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS redemptions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Reference code shown on screen (e.g. "RD12345")
  redemption_code VARCHAR(20) UNIQUE NOT NULL,
  campaign_id     UUID NOT NULL REFERENCES campaigns(id),
  creator_id      UUID NOT NULL REFERENCES users(id),
  qr_id           UUID NOT NULL REFERENCES qr_codes(id),
  -- Customer info (may be anonymous)
  customer_name   VARCHAR(200),
  customer_phone  VARCHAR(20),
  device_fingerprint VARCHAR(255),
  -- Status lifecycle
  status          VARCHAR(20) NOT NULL DEFAULT 'claimed'
                  CHECK (status IN ('claimed', 'confirmed', 'reversed')),
  -- Geo at claim time
  claim_lat       NUMERIC(10, 7),
  claim_lng       NUMERIC(10, 7),
  claim_accuracy  NUMERIC(6, 2),
  -- Geo at confirm time (business device location)
  confirm_lat     NUMERIC(10, 7),
  confirm_lng     NUMERIC(10, 7),
  confirm_accuracy NUMERIC(6, 2),
  -- Distance from campaign location at confirm (meters)
  geo_distance_m  NUMERIC(10, 2),
  geo_verified    BOOLEAN NOT NULL DEFAULT FALSE,
  -- Timestamps
  claimed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  confirmed_at    TIMESTAMPTZ,
  -- Bill amount (optionally entered by business)
  bill_amount     NUMERIC(10, 2),
  -- Commission calculated at confirm time
  commission_amount NUMERIC(10, 2),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_redemptions_campaign_id     ON redemptions(campaign_id);
CREATE INDEX IF NOT EXISTS idx_redemptions_creator_id      ON redemptions(creator_id);
CREATE INDEX IF NOT EXISTS idx_redemptions_status          ON redemptions(status);
CREATE INDEX IF NOT EXISTS idx_redemptions_confirmed_at    ON redemptions(confirmed_at);
CREATE INDEX IF NOT EXISTS idx_redemptions_redemption_code ON redemptions(redemption_code);
CREATE INDEX IF NOT EXISTS idx_redemptions_qr_id           ON redemptions(qr_id);

-- ─────────────────────────────────────────────────────────
-- 8. EARNINGS (one row per confirmed redemption)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS earnings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  redemption_id   UUID UNIQUE NOT NULL REFERENCES redemptions(id) ON DELETE CASCADE,
  creator_id      UUID NOT NULL REFERENCES users(id),
  campaign_id     UUID NOT NULL REFERENCES campaigns(id),
  amount          NUMERIC(10, 2) NOT NULL,
  -- Lifecycle: PENDING → AVAILABLE → PAID  |  PENDING → DISPUTED → REVERSED
  status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'available', 'paid', 'disputed', 'reversed')),
  -- 48-hour hold
  available_at    TIMESTAMPTZ NOT NULL,   -- confirmed_at + 48h
  paid_at         TIMESTAMPTZ,
  payout_id       UUID,                  -- FK added after payouts table created (below)
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_earnings_creator_id    ON earnings(creator_id);
CREATE INDEX IF NOT EXISTS idx_earnings_status        ON earnings(status);
CREATE INDEX IF NOT EXISTS idx_earnings_available_at  ON earnings(available_at);
CREATE INDEX IF NOT EXISTS idx_earnings_payout_id     ON earnings(payout_id);
CREATE INDEX IF NOT EXISTS idx_earnings_campaign_id   ON earnings(campaign_id);

-- ─────────────────────────────────────────────────────────
-- 9. DISPUTES (business raises, admin resolves)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS disputes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  redemption_id   UUID NOT NULL REFERENCES redemptions(id) ON DELETE CASCADE,
  earning_id      UUID NOT NULL REFERENCES earnings(id)    ON DELETE CASCADE,
  business_id     UUID NOT NULL REFERENCES users(id),
  reason          TEXT NOT NULL,
  evidence_urls   TEXT[],                -- array of image/doc URLs
  status          VARCHAR(20) NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'under_review', 'approved', 'rejected')),
  -- Admin resolution
  admin_id        UUID REFERENCES users(id),
  admin_notes     TEXT,
  resolved_at     TIMESTAMPTZ,
  -- Window enforcement: dispute must be filed within 48h of confirmed_at
  filed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_disputes_redemption_id ON disputes(redemption_id);
CREATE INDEX IF NOT EXISTS idx_disputes_business_id   ON disputes(business_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status        ON disputes(status);

-- ─────────────────────────────────────────────────────────
-- 10. PAYOUTS (creator payout requests)
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payouts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id      UUID NOT NULL REFERENCES users(id),
  amount          NUMERIC(12, 2) NOT NULL,
  status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'processing', 'paid', 'failed')),
  -- Payment reference
  utr_number      VARCHAR(100),          -- bank UTR or UPI ref
  payout_method   VARCHAR(20),
  bank_account    VARCHAR(50),
  bank_ifsc       VARCHAR(20),
  upi_id          VARCHAR(100),
  -- Timestamps
  requested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at    TIMESTAMPTZ,
  paid_at         TIMESTAMPTZ,
  admin_id        UUID REFERENCES users(id),
  admin_notes     TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payouts_creator_id ON payouts(creator_id);
CREATE INDEX IF NOT EXISTS idx_payouts_status     ON payouts(status);

-- ─────────────────────────────────────────────────────────
-- 11. USER SETTINGS + NOTIFICATIONS
-- ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  notification_settings JSONB NOT NULL DEFAULT '{"email_campaigns":true,"email_earnings":true,"push_redemptions":true,"sms_payouts":false}'::jsonb,
  privacy_settings JSONB NOT NULL DEFAULT '{"two_factor":false,"show_profile_publicly":true,"allow_data_analytics":true}'::jsonb,
  creator_preferences JSONB NOT NULL DEFAULT '{"auto_join_nearby":false,"show_earnings_publicly":false,"preferred_niche":""}'::jsonb,
  campaign_preferences JSONB NOT NULL DEFAULT '{"auto_approve_creator_joins":false,"require_geo_verified_redemptions":true,"email_new_redemptions":true}'::jsonb,
  connected_apps JSONB NOT NULL DEFAULT '[{"id":"instagram","name":"Instagram","connected":false,"icon":"IG"},{"id":"youtube","name":"YouTube","connected":false,"icon":"YT"},{"id":"google","name":"Google Analytics","connected":false,"icon":"GA"}]'::jsonb,
  team_members JSONB NOT NULL DEFAULT '[{"id":"owner","name":"You (Owner)","email":"owner@business.com","role":"admin"}]'::jsonb,
  api_settings JSONB NOT NULL DEFAULT '{"webhook_url":""}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  description TEXT,
  type VARCHAR(40) NOT NULL DEFAULT 'info',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id_created_at ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read);

-- ─────────────────────────────────────────────────────────
-- FK: earnings → payouts (circular ref resolved after both tables exist)
-- ─────────────────────────────────────────────────────────
ALTER TABLE earnings
  DROP CONSTRAINT IF EXISTS fk_earnings_payout,
  ADD CONSTRAINT fk_earnings_payout
    FOREIGN KEY (payout_id) REFERENCES payouts(id) ON DELETE SET NULL;

-- ─────────────────────────────────────────────────────────
-- Auto-update updated_at trigger
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['users','creator_profiles','business_profiles','campaigns','earnings','user_settings']
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%I_updated_at ON %I;
       CREATE TRIGGER trg_%I_updated_at
       BEFORE UPDATE ON %I
       FOR EACH ROW EXECUTE FUNCTION set_updated_at();',
      tbl, tbl, tbl, tbl
    );
  END LOOP;
END;
$$;
