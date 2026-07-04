import type { Env, JobKind, JobRow } from "../bindings";
import {
  createJob,
  deleteJob,
  findIdempotentJob,
  getJob,
  recordIdempotentJob,
  setJobStatus,
} from "./db";

export interface EnqueueInput {
  clientId?: string | null;
  idempotencyKey?: string;
  inputKey: string | null;
  kind: JobKind;
  params: unknown;
  scope: string;
}

export interface EnqueueResult {
  idempotentHit: boolean;
  job: JobRow;
}

export const createAndEnqueue = async (
  env: Env,
  input: EnqueueInput
): Promise<EnqueueResult> => {
  if (input.idempotencyKey) {
    const existingId = await findIdempotentJob(
      env,
      input.scope,
      input.idempotencyKey
    );
    const existing = existingId ? await getJob(env, existingId) : null;
    if (existing) {
      return { idempotentHit: true, job: existing };
    }
  }

  const job = await createJob(env, {
    clientId: input.clientId,
    inputKey: input.inputKey,
    kind: input.kind,
    params: input.params,
    status: "queued",
  });

  if (input.idempotencyKey) {
    const recorded = await recordIdempotentJob(
      env,
      input.scope,
      input.idempotencyKey,
      job.id
    );
    if (!recorded) {
      const winnerId = await findIdempotentJob(
        env,
        input.scope,
        input.idempotencyKey
      );
      const winner =
        winnerId && winnerId !== job.id ? await getJob(env, winnerId) : null;
      if (winner) {
        await deleteJob(env, job.id);
        return { idempotentHit: true, job: winner };
      }
    }
  }

  try {
    await env.JOBS_QUEUE.send({ job_id: job.id, kind: input.kind });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await setJobStatus(env, job.id, "failed", {
      error: `enqueue failed: ${message}`,
    });
    throw error;
  }

  return { idempotentHit: false, job };
};
