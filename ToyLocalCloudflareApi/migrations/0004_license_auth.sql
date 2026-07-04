ALTER TABLE api_credentials ADD COLUMN activation_id TEXT;
ALTER TABLE api_credentials ADD COLUMN expires_at TEXT;

CREATE TABLE IF NOT EXISTS license_keys (
  id TEXT PRIMARY KEY,
  key_hash TEXT NOT NULL UNIQUE,
  user_id TEXT REFERENCES users(id),
  email TEXT NOT NULL,
  status TEXT NOT NULL,
  max_activations INTEGER NOT NULL DEFAULT 2,
  created_at TEXT NOT NULL,
  activated_at TEXT,
  revoked_at TEXT,
  expires_at TEXT,
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_license_keys_user_id ON license_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_license_keys_email ON license_keys(email);
CREATE INDEX IF NOT EXISTS idx_license_keys_status ON license_keys(status);

CREATE TABLE IF NOT EXISTS license_activations (
  id TEXT PRIMARY KEY,
  license_id TEXT NOT NULL REFERENCES license_keys(id),
  user_id TEXT NOT NULL REFERENCES users(id),
  device_id TEXT NOT NULL,
  device_name TEXT,
  app_version TEXT,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_seen_at TEXT,
  revoked_at TEXT,
  UNIQUE(license_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_license_activations_license_id
  ON license_activations(license_id);
CREATE INDEX IF NOT EXISTS idx_license_activations_user_id
  ON license_activations(user_id);
CREATE INDEX IF NOT EXISTS idx_license_activations_status
  ON license_activations(status);
