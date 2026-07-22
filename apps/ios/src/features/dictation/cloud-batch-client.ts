import type {
  DictationPlan,
  TranscriptionArtifact,
} from "@/features/dictation/dictation-types";
import { makeWaveFile } from "@/features/dictation/recording-file";
import {
  configuredVoiceClient,
  voiceApiError,
  type FetchImplementation,
} from "@/lib/peacockery-voice-client";

async function transcribeCloudBatch(
  plan: DictationPlan,
  audioChunks: ArrayBuffer[],
  fetchImplementation: FetchImplementation = fetch,
): Promise<TranscriptionArtifact> {
  const audio = makeWaveFile(audioChunks);
  const voice = configuredVoiceClient(plan.credential, fetchImplementation);
  const reservationResponse = await voice.POST("/v1/uploads", {
    body: {
      content_type: "audio/wav",
      filename: `${plan.requestId}.wav`,
      size_bytes: audio.byteLength,
    },
  });
  if (reservationResponse.error) {
    throw voiceApiError(
      "Audio upload reservation",
      reservationResponse.response,
      reservationResponse.error,
    );
  }
  const reservation = reservationResponse.data;
  const uploadId = reservation.upload_id;
  const inputKey = reservation.input_key;
  const transfer = reservation.transfer;
  if (transfer.kind !== "single") {
    throw new Error("The upload service returned an unsupported transfer.");
  }
  const uploadResponse = await fetchImplementation(transfer.url, {
    body: audio as unknown as BodyInit,
    headers: transfer.headers,
    method: "PUT",
  });
  if (!uploadResponse.ok) {
    throw new Error(`Audio upload failed (${uploadResponse.status}).`);
  }
  const completionResponse = await voice.POST(
    "/v1/uploads/{upload_id}/complete",
    {
      body: { parts: [] },
      params: { path: { upload_id: uploadId } },
    },
  );
  if (completionResponse.error) {
    throw voiceApiError(
      "Audio upload completion",
      completionResponse.response,
      completionResponse.error,
    );
  }

  const requestBody = {
    asr_model: plan.executor.model,
    diarize: plan.mode.identifySpeakers,
    input_key: inputKey,
    language: plan.mode.language ?? undefined,
    sync: true,
  };
  const transcriptionResponse = await voice.POST("/v1/transcriptions", {
    body: requestBody,
    params: {
      header: {
        "idempotency-key": plan.requestId,
      },
    },
  });
  if (transcriptionResponse.error) {
    throw voiceApiError(
      "Batch transcription",
      transcriptionResponse.response,
      transcriptionResponse.error,
    );
  }
  let job = transcriptionResponse.data;
  const deadline = Date.now() + 120_000;
  while (
    job.status === "pending" ||
    job.status === "queued" ||
    job.status === "running"
  ) {
    if (Date.now() >= deadline) {
      throw new Error("Batch transcription took longer than two minutes.");
    }
    await wait(300);
    const jobResponse = await voice.GET("/v1/jobs/{job_id}", {
      params: { path: { job_id: job.job_id } },
    });
    if (jobResponse.error) {
      throw voiceApiError(
        "Batch transcription status",
        jobResponse.response,
        jobResponse.error,
      );
    }
    job = jobResponse.data;
  }
  if (job.status !== "succeeded") {
    throw new Error(jobError(job));
  }
  return transcriptionArtifact(job.result);
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

function jobError(job: { error: string | null }) {
  if (typeof job.error === "string") return job.error;
  return "Batch transcription failed.";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function wait(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export { transcribeCloudBatch };
