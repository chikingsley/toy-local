import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { isDeepStrictEqual } from "node:util";

import { afterEach, describe, expect, it } from "vitest";

import {
  closeRealtimeSockets,
  type RealtimeCase,
  runRealtimeSession,
} from "./realtime-harness";

const baseUrl = "https://timbervox.peacockery.studio";
const fixturePath = resolve("tests/fixtures/audio/asr-smoke.wav");
const exhaustiveTestsEnabled =
  process.env.TIMBERVOX_EXHAUSTIVE_LIVE_TESTS === "1";

interface CatalogRoute {
  model: string;
  provider: string;
  upstream_model: string;
}

interface CatalogModel {
  id: string;
  kind: "language" | "transcription";
  provider: string;
  routes?: {
    batch?: CatalogRoute;
    realtime?: CatalogRoute;
  };
  upstream_model: string;
}

interface CatalogPayload {
  models: CatalogModel[];
  presentation_schema_version: number;
}

interface MatrixFailure {
  error: string;
  model: string;
  route: string;
}

interface JobPayload {
  error?: string | null;
  job_id: string;
  result?: {
    provenance?: Record<string, unknown>;
    text?: string;
  } | null;
  status: string;
}

const configuredApiKey = (): string | null =>
  process.env.TIMBERVOX_API_KEY?.trim() || null;

const authorizationHeaders = (apiKey: string): Record<string, string> => ({
  Authorization: `Bearer ${apiKey}`,
});

const jsonRequest = (
  apiKey: string,
  body: Record<string, unknown>
): RequestInit => ({
  body: JSON.stringify(body),
  headers: {
    ...authorizationHeaders(apiKey),
    "content-type": "application/json",
  },
  method: "POST",
});

const responseDetail = async (response: Response): Promise<string> => {
  const body = (await response.text()).trim();
  return body ? body.slice(0, 1000) : "empty response body";
};

const requireOk = async (response: Response, label: string): Promise<void> => {
  if (!response.ok) {
    throw new Error(
      `${label} returned HTTP ${response.status}: ${await responseDetail(response)}`
    );
  }
};

const assertCondition = (
  condition: boolean,
  message: string
): asserts condition => {
  if (!condition) {
    throw new Error(message);
  }
};

const fetchCatalog = async (apiKey: string): Promise<CatalogPayload> => {
  const response = await fetch(`${baseUrl}/v1/models`, {
    headers: authorizationHeaders(apiKey),
  });
  await requireOk(response, "model catalog");
  const payload = (await response.json()) as CatalogPayload;
  assertCondition(
    payload.presentation_schema_version === 1,
    `unexpected catalog schema ${payload.presentation_schema_version}`
  );
  return payload;
};

const errorMessage = (error: unknown): string =>
  error instanceof Error ? error.message : String(error);

const progress = (route: string, model: string, status: "failed" | "ok") => {
  process.stdout.write(`[advertised-matrix] ${route} ${model}: ${status}\n`);
};

const runMatrix = async (
  route: string,
  models: CatalogModel[],
  run: (model: CatalogModel) => Promise<void>
): Promise<MatrixFailure[]> => {
  const failures: MatrixFailure[] = [];
  for (const model of models) {
    try {
      // biome-ignore lint/performance/noAwaitInLoops: route probes stay sequential to avoid upstream burst limits.
      await run(model);
      progress(route, model.id, "ok");
    } catch (error) {
      progress(route, model.id, "failed");
      failures.push({ error: errorMessage(error), model: model.id, route });
    }
  }
  return failures;
};

const runTextModel = async (
  apiKey: string,
  model: CatalogModel
): Promise<void> => {
  const response = await fetch(
    `${baseUrl}/v1/text`,
    jsonRequest(apiKey, {
      maxOutputTokens: 128,
      messages: [
        {
          content: "Reply with exactly one short word meaning ready.",
          role: "user",
        },
      ],
      model: model.id,
    })
  );
  await requireOk(response, `${model.id} text`);
  const result = (await response.json()) as Record<string, unknown>;
  assertCondition(
    result.model === model.id,
    `${model.id} changed public model`
  );
  assertCondition(
    result.outputType === "text",
    `${model.id} returned ${String(result.outputType)} output`
  );
  assertCondition(
    result.provider === model.provider,
    `${model.id} changed public provider to ${String(result.provider)}`
  );
  assertCondition(
    result.upstreamModel === model.upstream_model,
    `${model.id} changed upstream model to ${String(result.upstreamModel)}`
  );
  assertCondition(
    String(result.text ?? "").trim().length > 0,
    `${model.id} returned empty text`
  );
};

const streamData = (body: string): Record<string, unknown>[] =>
  body.split("\n\n").flatMap((frame) => {
    const data = frame
      .split("\n")
      .filter((line) => line.startsWith("data:"))
      .map((line) => line.slice("data:".length).trimStart())
      .join("\n");
    return data ? [JSON.parse(data) as Record<string, unknown>] : [];
  });

const runTextStreamModel = async (
  apiKey: string,
  model: CatalogModel
): Promise<void> => {
  const response = await fetch(
    `${baseUrl}/v1/text/stream`,
    jsonRequest(apiKey, {
      maxOutputTokens: 128,
      messages: [
        {
          content: "Reply with exactly one short word meaning ready.",
          role: "user",
        },
      ],
      model: model.id,
    })
  );
  await requireOk(response, `${model.id} text stream`);
  assertCondition(
    response.headers.get("content-type")?.includes("text/event-stream") ===
      true,
    `${model.id} did not return an event stream`
  );
  const events = streamData(await response.text());
  const started = events.at(0);
  assertCondition(
    started?.type === "stream.started",
    `${model.id} did not start`
  );
  assertCondition(
    started.model === model.id,
    `${model.id} stream changed model`
  );
  assertCondition(
    started.provider === model.provider,
    `${model.id} stream changed public provider`
  );
  assertCondition(
    started.upstream_model === model.upstream_model,
    `${model.id} stream changed upstream model`
  );
  assertCondition(
    events.some(
      (event) =>
        event.type === "text.delta" && String(event.delta ?? "").length > 0
    ),
    `${model.id} stream emitted no text delta`
  );
  assertCondition(
    events.at(-1)?.type === "stream.completed",
    `${model.id} stream ended with ${String(events.at(-1)?.type)}`
  );
};

const reserveFixtureUpload = async (apiKey: string): Promise<string> => {
  const audio = await readFile(fixturePath);
  const reservationResponse = await fetch(
    `${baseUrl}/v1/uploads`,
    jsonRequest(apiKey, {
      content_type: "audio/wav",
      filename: "advertised-model-matrix.wav",
      size_bytes: audio.byteLength,
    })
  );
  await requireOk(reservationResponse, "upload reservation");
  const reservation = (await reservationResponse.json()) as {
    input_key: string;
    transfer: {
      headers: Record<string, string>;
      kind: string;
      url: string;
    };
    upload_id: string;
  };
  assertCondition(
    reservation.transfer.kind === "single",
    `fixture reservation used ${reservation.transfer.kind} transfer`
  );
  const uploadResponse = await fetch(reservation.transfer.url, {
    body: audio,
    headers: reservation.transfer.headers,
    method: "PUT",
  });
  await requireOk(uploadResponse, "fixture upload");
  const completionResponse = await fetch(
    `${baseUrl}/v1/uploads/${reservation.upload_id}/complete`,
    jsonRequest(apiKey, { parts: [] })
  );
  await requireOk(completionResponse, "upload completion");
  return reservation.input_key;
};

const waitForTerminalJob = async (
  apiKey: string,
  initial: JobPayload
): Promise<JobPayload> => {
  let job = initial;
  const deadline = Date.now() + 90_000;
  while (["pending", "queued", "running"].includes(job.status)) {
    if (Date.now() >= deadline) {
      throw new Error(`${job.job_id} did not finish within 90 seconds`);
    }
    // biome-ignore lint/performance/noAwaitInLoops: this is bounded job polling.
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 2000));
    const response = await fetch(`${baseUrl}/v1/jobs/${job.job_id}`, {
      headers: authorizationHeaders(apiKey),
    });
    await requireOk(response, `${job.job_id} status`);
    job = (await response.json()) as JobPayload;
  }
  return job;
};

const runBatchModel = async (
  apiKey: string,
  inputKey: string,
  model: CatalogModel
): Promise<void> => {
  const route = model.routes?.batch;
  if (!route) {
    throw new Error(`${model.id} has no advertised batch route`);
  }
  const response = await fetch(
    `${baseUrl}/v1/transcriptions`,
    jsonRequest(apiKey, {
      asr_model: model.id,
      input_key: inputKey,
      sync: true,
    })
  );
  await requireOk(response, `${model.id} batch`);
  const job = await waitForTerminalJob(
    apiKey,
    (await response.json()) as JobPayload
  );
  if (job.status !== "succeeded") {
    throw new Error(
      `${model.id} ended ${job.status}: ${job.error ?? "no error"}`
    );
  }
  const provenance = job.result?.provenance;
  assertCondition(
    provenance?.model === model.id,
    `${model.id} changed batch model`
  );
  assertCondition(
    provenance.provider === model.provider,
    `${model.id} changed batch public provider`
  );
  assertCondition(
    provenance.transport === "batch",
    `${model.id} returned ${String(provenance.transport)} transport`
  );
  assertCondition(
    provenance.upstream_model === route.upstream_model,
    `${model.id} changed batch upstream model`
  );
  assertCondition(
    String(job.result?.text ?? "").trim().length > 0,
    `${model.id} returned empty batch text`
  );
};

const realtimeCase = (model: CatalogModel): RealtimeCase => {
  const route = model.routes?.realtime;
  if (!route) {
    throw new Error(`${model.id} has no advertised realtime route`);
  }
  if (!["deepgram", "elevenlabs", "mistral"].includes(route.provider)) {
    throw new Error(
      `${model.id} has unsupported realtime provider ${route.provider}`
    );
  }
  return {
    model: route.model,
    provider: route.provider as RealtimeCase["provider"],
  };
};

const runRealtimeModel = async (
  apiKey: string,
  model: CatalogModel
): Promise<void> => {
  const testCase = realtimeCase(model);
  const events = await runRealtimeSession(testCase, apiKey);
  const started = events.find((event) => event.type === "session.started");
  const completed = events.find((event) => event.type === "session.completed");
  const result = completed?.result as Record<string, unknown> | undefined;
  const provenance = result?.provenance as Record<string, unknown> | undefined;
  assertCondition(started?.protocol_version === 1, `${model.id} did not start`);
  assertCondition(
    completed?.protocol_version === 1,
    `${model.id} did not complete`
  );
  assertCondition(
    provenance?.provider === model.provider,
    `${model.id} changed realtime public provider`
  );
  assertCondition(
    String(result?.text ?? "").trim().length > 0,
    `${model.id} returned empty realtime text`
  );

  const recoveryResponse = await fetch(
    `${baseUrl}/v1/realtime/sessions/${started?.session_id}`,
    { headers: authorizationHeaders(apiKey) }
  );
  await requireOk(recoveryResponse, `${model.id} realtime recovery`);
  const recovered = (await recoveryResponse.json()) as Record<string, unknown>;
  assertCondition(
    recovered.type === "session.completed",
    `${model.id} recovered ${String(recovered.type)}`
  );
  assertCondition(
    isDeepStrictEqual(recovered.result, completed?.result),
    `${model.id} recovered a different result`
  );
};

afterEach(() => {
  closeRealtimeSockets();
});

describe.sequential("every authenticated, advertised model route", () => {
  it("generates and streams through every advertised language model", async ({
    skip,
  }) => {
    const apiKey = configuredApiKey();
    if (!(exhaustiveTestsEnabled && apiKey)) {
      skip(
        "TIMBERVOX_EXHAUSTIVE_LIVE_TESTS=1 and TIMBERVOX_API_KEY are required"
      );
      return;
    }
    const catalog = await fetchCatalog(apiKey);
    const models = catalog.models.filter((model) => model.kind === "language");
    expect(models.length).toBeGreaterThan(0);
    const textFailures = await runMatrix("text", models, (model) =>
      runTextModel(apiKey, model)
    );
    const streamFailures = await runMatrix("text-stream", models, (model) =>
      runTextStreamModel(apiKey, model)
    );
    const failures = [...textFailures, ...streamFailures];
    expect(failures, JSON.stringify(failures, null, 2)).toEqual([]);
  }, 900_000);

  it("transcribes through every advertised batch route", async ({ skip }) => {
    const apiKey = configuredApiKey();
    if (!(exhaustiveTestsEnabled && apiKey)) {
      skip(
        "TIMBERVOX_EXHAUSTIVE_LIVE_TESTS=1 and TIMBERVOX_API_KEY are required"
      );
      return;
    }
    const catalog = await fetchCatalog(apiKey);
    const models = catalog.models.filter(
      (model) => model.kind === "transcription" && model.routes?.batch
    );
    expect(models.length).toBeGreaterThan(0);
    const inputKey = await reserveFixtureUpload(apiKey);
    const failures = await runMatrix("batch", models, (model) =>
      runBatchModel(apiKey, inputKey, model)
    );
    expect(failures, JSON.stringify(failures, null, 2)).toEqual([]);
  }, 900_000);

  it("streams and recovers every advertised realtime route", async ({
    skip,
  }) => {
    const apiKey = configuredApiKey();
    if (!(exhaustiveTestsEnabled && apiKey)) {
      skip(
        "TIMBERVOX_EXHAUSTIVE_LIVE_TESTS=1 and TIMBERVOX_API_KEY are required"
      );
      return;
    }
    const catalog = await fetchCatalog(apiKey);
    const models = catalog.models.filter(
      (model) => model.kind === "transcription" && model.routes?.realtime
    );
    expect(models.length).toBeGreaterThan(0);
    const failures = await runMatrix("realtime", models, (model) =>
      runRealtimeModel(apiKey, model)
    );
    expect(failures, JSON.stringify(failures, null, 2)).toEqual([]);
  }, 600_000);
});
