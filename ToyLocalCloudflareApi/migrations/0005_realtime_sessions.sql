CREATE TABLE IF NOT EXISTS realtime_sessions (
  id TEXT PRIMARY KEY,
  client_id TEXT,
  provider TEXT NOT NULL,
  model TEXT NOT NULL,
  upstream_model TEXT NOT NULL,
  language TEXT,
  status TEXT NOT NULL,
  transcript TEXT,
  transcript_json_key TEXT,
  transcript_text_key TEXT,
  audio_bytes INTEGER NOT NULL DEFAULT 0,
  audio_seconds REAL,
  message_count INTEGER NOT NULL DEFAULT 0,
  error TEXT,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_realtime_sessions_client_created
  ON realtime_sessions(client_id, created_at);
CREATE INDEX IF NOT EXISTS idx_realtime_sessions_provider_model
  ON realtime_sessions(provider, model);
CREATE INDEX IF NOT EXISTS idx_realtime_sessions_status
  ON realtime_sessions(status);
