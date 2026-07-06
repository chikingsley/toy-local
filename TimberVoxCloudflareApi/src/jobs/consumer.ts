import type { Env, JobStatus, QueueJobMessage } from "../bindings";
import { getJob, setJobStatus } from "./db";
import { TransientProviderError } from "./provider-errors";
import { runTranscriptionJob } from "./transcriptions";

const JOBS_QUEUE_NAME = "timbervox-jobs";
const JOBS_DLQ_QUEUE_NAME = "timbervox-jobs-dlq";

const isTerminal = (status: JobStatus): boolean =>
  status === "succeeded" || status === "failed";

const processOne = async (
  env: Env,
  message: Message<QueueJobMessage>
): Promise<void> => {
  if (message.body.kind === "validation") {
    console.log(
      JSON.stringify({
        event: "queue.validation",
        validation_id: message.body.validation_id,
      })
    );
    return;
  }

  const job = await getJob(env, message.body.job_id);
  if (!job || isTerminal(job.status)) {
    return;
  }

  if (job.kind !== "transcription") {
    await setJobStatus(env, job.id, "failed", {
      error: `unsupported job kind: ${job.kind}`,
      progress: 1,
    });
    return;
  }

  await runTranscriptionJob(env, job, { attempts: message.attempts });
};

const processDeadLetter = async (
  env: Env,
  message: Message<QueueJobMessage>
): Promise<void> => {
  if (message.body.kind === "validation") {
    console.log(
      JSON.stringify({
        event: "queue.validation.dlq",
        validation_id: message.body.validation_id,
      })
    );
    return;
  }

  const job = await getJob(env, message.body.job_id);
  if (!job || isTerminal(job.status)) {
    return;
  }

  const previous = job.error ? ` Last error: ${job.error}` : "";
  await setJobStatus(env, job.id, "failed", {
    error:
      `queue retries exhausted; message '${message.id}' reached '${JOBS_DLQ_QUEUE_NAME}' ` +
      `after ${message.attempts} attempts.${previous}`,
    progress: 1,
  });
};

const processMessages = async (
  env: Env,
  messages: readonly Message<QueueJobMessage>[],
  handler: (env: Env, message: Message<QueueJobMessage>) => Promise<void>
): Promise<void> => {
  for (const message of messages) {
    try {
      await handler(env, message);
      message.ack();
    } catch (error) {
      if (error instanceof TransientProviderError) {
        message.retry({ delaySeconds: error.retryDelaySeconds });
        continue;
      }
      message.retry();
    }
  }
};

export const handleJobs = async (
  batch: MessageBatch<QueueJobMessage>,
  env: Env
): Promise<void> => {
  if (batch.queue === JOBS_DLQ_QUEUE_NAME) {
    await processMessages(env, batch.messages, processDeadLetter);
    return;
  }

  if (batch.queue !== JOBS_QUEUE_NAME) {
    throw new Error(`unexpected queue: ${batch.queue}`);
  }

  await processMessages(env, batch.messages, processOne);
};
