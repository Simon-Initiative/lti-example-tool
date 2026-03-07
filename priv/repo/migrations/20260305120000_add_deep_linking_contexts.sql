-- +goose Up
CREATE TABLE deep_linking_contexts (
  id SERIAL PRIMARY KEY,
  context_token TEXT NOT NULL UNIQUE,
  iss TEXT NOT NULL,
  aud TEXT NOT NULL,
  deployment_id TEXT NOT NULL,
  deep_link_return_url TEXT NOT NULL,
  request_data TEXT,
  accept_types TEXT NOT NULL,
  accept_multiple BOOLEAN,
  accept_lineitem BOOLEAN,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  consumed_at TIMESTAMP
);

CREATE INDEX deep_linking_contexts_expires_at_idx
  ON deep_linking_contexts (expires_at);

-- +goose Down
DROP INDEX IF EXISTS deep_linking_contexts_expires_at_idx;
DROP TABLE deep_linking_contexts;
