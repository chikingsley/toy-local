export interface Env {
  ANTHROPIC_API_KEY?: string;
  ARTIFACTS: R2Bucket;
  CEREBRAS_API_KEY?: string;
  CLOUDFLARE_ACCOUNT_ID?: string;
  CLOUDFLARE_ANALYTICS_API_TOKEN?: string;
  DB: D1Database;
  DEEPGRAM_API_KEY?: string;
  DEEPSEEK_API_KEY?: string;
  ELEVENLABS_API_KEY?: string;
  GOOGLE_GENERATIVE_AI_API_KEY?: string;
  GROQ_API_KEY?: string;
  JOBS_DLQ: Queue<QueueJobMessage>;
  JOBS_QUEUE: Queue<QueueJobMessage>;
  MISTRAL_API_KEY: string;
  OPENAI_API_KEY?: string;
  R2_ACCESS_KEY_ID?: string;
  R2_BUCKET_NAME?: string;
  R2_SECRET_ACCESS_KEY?: string;
  REALTIME_SESSIONS: DurableObjectNamespace;
  SUPERWHISPER_USER_AGENT?: string;
  SUPERWHISPER_X_ID?: string;
  SUPERWHISPER_X_LICENSE?: string;
  SUPERWHISPER_X_SIGNATURE?: string;
  TIMBERVOX_ADMIN_TOKEN?: string;
  TIMBERVOX_API_KEYS?: string;
  TIMBERVOX_USAGE_DATASET?: string;
  USAGE_ANALYTICS?: AnalyticsEngineDataset;
  ZAI_API_KEY?: string;
}

export type JobKind = "transcription";

export type QueueJobMessage =
  | {
      job_id: string;
      kind: JobKind;
    }
  | {
      kind: "validation";
      validation_id: string;
    };

export type JobStatus =
  | "pending"
  | "queued"
  | "running"
  | "succeeded"
  | "failed";

export interface JobRow {
  client_id: string | null;
  completed_at: string | null;
  created_at: string;
  credential_id: string | null;
  error: string | null;
  id: string;
  input_key: string | null;
  kind: JobKind;
  owner_user_id: string | null;
  params_json: string | null;
  progress: number;
  queued_at: string | null;
  result_json: string | null;
  started_at: string | null;
  status: JobStatus;
  updated_at: string;
}
