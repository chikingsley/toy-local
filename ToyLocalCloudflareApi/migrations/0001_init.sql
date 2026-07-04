CREATE TABLE IF NOT EXISTS uploads (
  id TEXT PRIMARY KEY,
  input_key TEXT NOT NULL UNIQUE,
  filename TEXT,
  content_type TEXT,
  size_bytes INTEGER,
  created_at TEXT NOT NULL,
  completed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_uploads_completed_at ON uploads(completed_at);

CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  status TEXT NOT NULL,
  input_key TEXT,
  params_json TEXT,
  result_json TEXT,
  error TEXT,
  progress REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  queued_at TEXT,
  started_at TEXT,
  completed_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_jobs_input_key ON jobs(input_key);

CREATE TABLE IF NOT EXISTS idempotency_keys (
  scope TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  job_id TEXT NOT NULL REFERENCES jobs(id),
  created_at TEXT NOT NULL,
  PRIMARY KEY (scope, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_keys_job_id ON idempotency_keys(job_id);
