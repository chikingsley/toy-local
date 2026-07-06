import type { Env, JobKind, JobRow, JobStatus } from "../bindings";
import { newId } from "../lib/ids";

const nowIso = (): string => new Date().toISOString();

export const getJob = (env: Env, id: string): Promise<JobRow | null> =>
  env.DB.prepare("SELECT * FROM jobs WHERE id = ?").bind(id).first<JobRow>();

export const createJob = async (
  env: Env,
  input: {
    inputKey: string | null;
    kind: JobKind;
    clientId?: string | null;
    params: unknown;
    status: JobStatus;
  }
): Promise<JobRow> => {
  const id = newId("job");
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO jobs
      (id, kind, status, input_key, client_id, params_json, progress, created_at, updated_at, queued_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(
      id,
      input.kind,
      input.status,
      input.inputKey,
      input.clientId ?? null,
      JSON.stringify(input.params),
      input.status === "queued" ? 0 : 0.1,
      now,
      now,
      input.status === "queued" ? now : null
    )
    .run();
  const job = await getJob(env, id);
  if (!job) {
    throw new Error(`created job ${id} was not readable`);
  }
  return job;
};

export const deleteJob = async (env: Env, id: string): Promise<void> => {
  await env.DB.prepare("DELETE FROM jobs WHERE id = ?").bind(id).run();
};

export const findIdempotentJob = async (
  env: Env,
  scope: string,
  idempotencyKey: string
): Promise<string | null> => {
  const row = await env.DB.prepare(
    "SELECT job_id FROM idempotency_keys WHERE scope = ? AND idempotency_key = ?"
  )
    .bind(scope, idempotencyKey)
    .first<{ job_id: string }>();
  return row?.job_id ?? null;
};

export const recordIdempotentJob = async (
  env: Env,
  scope: string,
  idempotencyKey: string,
  jobId: string
): Promise<boolean> => {
  const result = await env.DB.prepare(
    `INSERT OR IGNORE INTO idempotency_keys
       (scope, idempotency_key, job_id, created_at)
     VALUES (?, ?, ?, ?)`
  )
    .bind(scope, idempotencyKey, jobId, nowIso())
    .run();
  return result.meta.changes > 0;
};

export const setJobStatus = async (
  env: Env,
  id: string,
  status: JobStatus,
  patch: {
    error?: string | null;
    progress?: number;
    result?: unknown;
    startedAt?: string;
  } = {}
): Promise<void> => {
  const now = nowIso();
  await env.DB.prepare(
    `UPDATE jobs
       SET status = ?,
           progress = COALESCE(?, progress),
           result_json = COALESCE(?, result_json),
           error = ?,
           started_at = COALESCE(?, started_at),
           completed_at = CASE WHEN ? IN ('succeeded', 'failed') THEN ? ELSE completed_at END,
           updated_at = ?
     WHERE id = ?`
  )
    .bind(
      status,
      patch.progress ?? null,
      patch.result === undefined ? null : JSON.stringify(patch.result),
      patch.error ?? null,
      patch.startedAt ?? null,
      status,
      now,
      now,
      id
    )
    .run();
};

export const jobView = (job: JobRow) => ({
  completed_at: job.completed_at,
  created_at: job.created_at,
  error: job.error,
  job_id: job.id,
  kind: job.kind,
  progress: job.progress,
  queued_at: job.queued_at,
  result: job.result_json ? JSON.parse(job.result_json) : null,
  started_at: job.started_at,
  status: job.status,
  updated_at: job.updated_at,
});
