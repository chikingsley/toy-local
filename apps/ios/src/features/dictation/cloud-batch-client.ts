import type {
  DictationPlan,
  TranscriptionArtifact,
} from "@/features/dictation/dictation-types";
import { makeWaveFile } from "@/features/dictation/recording-file";
import { API_ORIGIN } from "@/features/dictation/websocket-transport";

type FetchImplementation = typeof fetch;

async function transcribeCloudBatch(
  plan: DictationPlan,
  audioChunks: ArrayBuffer[],
  fetchImplementation: FetchImplementation = fetch,
): Promise<TranscriptionArtifact> {
  const audio = makeWaveFile(audioChunks);
  const reservation = await requestJSON(
    `${API_ORIGIN}/v1/uploads`,
    {
      body: JSON.stringify({
        content_type: "audio/wav",
        filename: `${plan.requestId}.wav`,
        size_bytes: audio.byteLength,
      }),
      headers: authorizedHeaders(plan.credential, true),
      method: "POST",
    },
    fetchImplementation,
  );
  const uploadId = requiredString(reservation, "upload_id");
  const inputKey = requiredString(reservation, "input_key");
  const transfer = requiredRecord(reservation, "transfer");
  if (transfer.kind !== "single") {
    throw new Error("The upload service returned an unsupported transfer.");
  }
  const uploadURL = requiredString(transfer, "url");
  const transferHeaders = stringRecord(transfer.headers);
  const uploadResponse = await fetchImplementation(uploadURL, {
    body: audio as unknown as BodyInit,
    headers: transferHeaders,
    method: "PUT",
  });
  if (!uploadResponse.ok) {
    throw new Error(`Audio upload failed (${uploadResponse.status}).`);
  }
  await requestJSON(
    `${API_ORIGIN}/v1/uploads/${encodeURIComponent(uploadId)}/complete`,
    {
      body: JSON.stringify({ parts: [] }),
      headers: authorizedHeaders(plan.credential, true),
      method: "POST",
    },
    fetchImplementation,
  );

  const requestBody: Record<string, unknown> = {
    asr_model: plan.executor.model,
    diarize: plan.mode.identifySpeakers,
    input_key: inputKey,
    sync: true,
  };
  if (plan.mode.language) requestBody.language = plan.mode.language;
  let job = await requestJSON(
    `${API_ORIGIN}/v1/transcriptions`,
    {
      body: JSON.stringify(requestBody),
      headers: {
        ...authorizedHeaders(plan.credential, true),
        "Idempotency-Key": plan.requestId,
      },
      method: "POST",
    },
    fetchImplementation,
  );
  const deadline = Date.now() + 120_000;
  while (job.status === "queued" || job.status === "running") {
    if (Date.now() >= deadline) {
      throw new Error("Batch transcription took longer than two minutes.");
    }
    const jobId = requiredString(job, "job_id");
    await wait(300);
    job = await requestJSON(
      `${API_ORIGIN}/v1/jobs/${encodeURIComponent(jobId)}`,
      { headers: authorizedHeaders(plan.credential), method: "GET" },
      fetchImplementation,
    );
  }
  if (job.status !== "succeeded") {
    throw new Error(jobError(job));
  }
  return transcriptionArtifact(job.result);
}

async function requestJSON(
  url: string,
  init: RequestInit,
  fetchImplementation: FetchImplementation,
) {
  const response = await fetchImplementation(url, init);
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(
      `TimberVox API error ${response.status}${detail ? `: ${detail}` : "."}`,
    );
  }
  const value: unknown = await response.json();
  if (!isRecord(value)) {
    throw new Error("The TimberVox API returned an invalid response.");
  }
  return value;
}

function authorizedHeaders(credential: string, json = false) {
  return {
    Accept: "application/json",
    Authorization: `Bearer ${credential}`,
    ...(json ? { "Content-Type": "application/json" } : {}),
  };
}

function transcriptionArtifact(value: unknown): TranscriptionArtifact {
  if (
    !isRecord(value) ||
    value.schema_version !== 2 ||
    typeof value.text !== "string"
  ) {
    throw new Error("Batch transcription returned an invalid artifact.");
  }
  return value as TranscriptionArtifact;
}

function requiredRecord(value: Record<string, unknown>, key: string) {
  const candidate = value[key];
  if (!isRecord(candidate)) {
    throw new Error(`The TimberVox API response is missing ${key}.`);
  }
  return candidate;
}

function requiredString(value: Record<string, unknown>, key: string) {
  const candidate = value[key];
  if (typeof candidate !== "string" || !candidate) {
    throw new Error(`The TimberVox API response is missing ${key}.`);
  }
  return candidate;
}

function stringRecord(value: unknown) {
  if (!isRecord(value)) return {};
  return Object.fromEntries(
    Object.entries(value).filter(
      (entry): entry is [string, string] => typeof entry[1] === "string",
    ),
  );
}

function jobError(job: Record<string, unknown>) {
  if (typeof job.error === "string") return job.error;
  if (isRecord(job.error) && typeof job.error.message === "string") {
    return job.error.message;
  }
  return "Batch transcription failed.";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function wait(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export { transcribeCloudBatch };
