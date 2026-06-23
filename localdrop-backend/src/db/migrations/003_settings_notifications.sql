CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  notification_settings JSONB NOT NULL DEFAULT '{"email_campaigns":true,"email_earnings":true,"push_redemptions":true,"sms_payouts":false}'::jsonb,
  privacy_settings JSONB NOT NULL DEFAULT '{"two_factor":false,"show_profile_publicly":true,"allow_data_analytics":true}'::jsonb,
  creator_preferences JSONB NOT NULL DEFAULT '{"auto_join_nearby":false,"show_earnings_publicly":false,"preferred_niche":""}'::jsonb,
  campaign_preferences JSONB NOT NULL DEFAULT '{"auto_approve_creator_joins":false,"require_geo_verified_redemptions":true,"email_new_redemptions":true}'::jsonb,
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

DROP TRIGGER IF EXISTS trg_user_settings_updated_at ON user_settings;
CREATE TRIGGER trg_user_settings_updated_at
BEFORE UPDATE ON user_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
