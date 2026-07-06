ALTER TABLE jobs ADD COLUMN client_id TEXT;

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS api_credentials (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES users(id),
  label TEXT,
  credential_hash TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_seen_at TEXT,
  revoked_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_api_credentials_user_id ON api_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_api_credentials_status ON api_credentials(status);

CREATE TABLE IF NOT EXISTS model_prices (
  provider TEXT NOT NULL,
  model TEXT NOT NULL,
  unit TEXT NOT NULL,
  input_micro_usd_per_unit REAL,
  output_micro_usd_per_unit REAL,
  effective_at TEXT NOT NULL,
  effective_until TEXT,
  source TEXT,
  PRIMARY KEY (provider, model, unit, effective_at)
);

CREATE INDEX IF NOT EXISTS idx_model_prices_lookup
  ON model_prices(provider, model, unit, effective_at);

CREATE TABLE IF NOT EXISTS request_logs (
  id TEXT PRIMARY KEY,
  account_key TEXT NOT NULL,
  user_id TEXT,
  client_id TEXT,
  request_id TEXT,
  job_id TEXT REFERENCES jobs(id),
  route TEXT,
  method TEXT,
  status INTEGER,
  kind TEXT NOT NULL,
  provider TEXT NOT NULL,
  model TEXT NOT NULL,
  upstream_model TEXT,
  asr_seconds REAL,
  input_tokens INTEGER,
  output_tokens INTEGER,
  total_tokens INTEGER,
  provider_latency_ms INTEGER,
  estimated_cost_micro_usd INTEGER,
  error TEXT,
  metadata_json TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_request_logs_account_created
  ON request_logs(account_key, created_at);
CREATE INDEX IF NOT EXISTS idx_request_logs_job_id ON request_logs(job_id);
CREATE INDEX IF NOT EXISTS idx_request_logs_provider_model
  ON request_logs(provider, model);
CREATE INDEX IF NOT EXISTS idx_request_logs_kind_created
  ON request_logs(kind, created_at);

CREATE TABLE IF NOT EXISTS usage_daily (
  day TEXT NOT NULL,
  account_key TEXT NOT NULL,
  user_id TEXT,
  client_id TEXT,
  kind TEXT NOT NULL,
  provider TEXT NOT NULL,
  model TEXT NOT NULL,
  upstream_model TEXT,
  request_count INTEGER NOT NULL DEFAULT 0,
  asr_seconds REAL NOT NULL DEFAULT 0,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  total_tokens INTEGER NOT NULL DEFAULT 0,
  provider_latency_ms INTEGER NOT NULL DEFAULT 0,
  estimated_cost_micro_usd INTEGER NOT NULL DEFAULT 0,
  first_request_at TEXT NOT NULL,
  last_request_at TEXT NOT NULL,
  PRIMARY KEY (day, account_key, kind, provider, model)
);

CREATE INDEX IF NOT EXISTS idx_usage_daily_account_day
  ON usage_daily(account_key, day);
