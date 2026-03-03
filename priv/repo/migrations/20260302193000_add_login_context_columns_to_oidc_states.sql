-- +goose Up
ALTER TABLE oidc_states
  ADD COLUMN IF NOT EXISTS target_link_uri TEXT,
  ADD COLUMN IF NOT EXISTS issuer TEXT,
  ADD COLUMN IF NOT EXISTS client_id TEXT;

UPDATE oidc_states
SET
  target_link_uri = COALESCE(target_link_uri, ''),
  issuer = COALESCE(issuer, ''),
  client_id = COALESCE(client_id, '');

ALTER TABLE oidc_states
  ALTER COLUMN target_link_uri SET NOT NULL,
  ALTER COLUMN issuer SET NOT NULL,
  ALTER COLUMN client_id SET NOT NULL;

-- +goose Down
ALTER TABLE oidc_states
  DROP COLUMN IF EXISTS client_id,
  DROP COLUMN IF EXISTS issuer,
  DROP COLUMN IF EXISTS target_link_uri;
