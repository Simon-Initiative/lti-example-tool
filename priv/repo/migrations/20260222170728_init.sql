-- +goose Up
CREATE TABLE registrations (
  id SERIAL PRIMARY KEY,
  name TEXT,
  issuer TEXT,
  client_id TEXT,
  auth_endpoint TEXT,
  access_token_endpoint TEXT,
  keyset_url TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(issuer, client_id)
);

CREATE TABLE deployments (
  id SERIAL PRIMARY KEY,
  deployment_id TEXT,
  registration_id INT REFERENCES registrations(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(deployment_id, registration_id)
);

CREATE TABLE oidc_states (
  state TEXT PRIMARY KEY,
  expires_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(state)
);

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  sub TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL DEFAULT '',
  issuer TEXT NOT NULL,
  audience TEXT NOT NULL,
  roles TEXT NOT NULL DEFAULT '',
  context_title TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(sub, issuer, audience)
);

CREATE TABLE tokens (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_type TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  used_at TIMESTAMP,
  revoked_at TIMESTAMP,
  replaced_by_token_hash TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(token_hash),
  CHECK (token_type IN ('bootstrap', 'refresh'))
);

CREATE TABLE nonces (
  nonce TEXT PRIMARY KEY,
  expires_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(nonce)
);

CREATE TABLE jwks (
  kid TEXT PRIMARY KEY,
  typ TEXT,
  alg TEXT,
  pem TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE active_jwk (
  kid TEXT REFERENCES jwks(kid)
);

-- +goose Down
DROP TABLE active_jwk;
DROP TABLE jwks;
DROP TABLE nonces;
DROP TABLE tokens;
DROP TABLE users;
DROP TABLE oidc_states;
DROP TABLE deployments;
DROP TABLE registrations;
