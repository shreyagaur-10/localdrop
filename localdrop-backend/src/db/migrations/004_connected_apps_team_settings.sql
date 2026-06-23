ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS connected_apps JSONB NOT NULL DEFAULT '[{"id":"instagram","name":"Instagram","connected":false,"icon":"IG"},{"id":"youtube","name":"YouTube","connected":false,"icon":"YT"},{"id":"google","name":"Google Analytics","connected":false,"icon":"GA"}]'::jsonb,
  ADD COLUMN IF NOT EXISTS team_members JSONB NOT NULL DEFAULT '[{"id":"owner","name":"You (Owner)","email":"owner@business.com","role":"admin"}]'::jsonb;
