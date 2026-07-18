import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import {
  resolveRealtimeAsrModel,
  resolveRealtimeLanguage,
} from "../ai/models/transcription-routes";
import type { RealtimeAsrModelEntry } from "../ai/models/types";
import { terminalSessionEvent } from "../ai/realtime/protocol";
import { TranscriptionArtifactSchema } from "../ai/transcription/artifact";
import { authenticateCredential } from "../auth/service";
import type { Env } from "../bindings";
import { newId } from "../lib/ids";
import {
  JsonErrorContent,
  RealtimeSessionResultResponse,
} from "./openapi-schemas";

type App = OpenAPIHono<{ Bindings: Env }>;

const BooleanQuery = z.string().transform((value, context) => {
  if (value === "true") {
    return true;
  }
  if (value === "false") {
    return false;
  }
  context.addIssue({
    code: "custom",
    message: "expected true or false",
  });
  return z.NEVER;
});

const RealtimeQuery = z
  .object({
    audio_format: z.string().min(1).optional(),
    channels: z.coerce.number().int().positive().optional(),
    detect_entities: BooleanQuery.optional(),
    diarize: BooleanQuery.optional(),
    diarize_model: z.enum(["latest", "v1"]).optional(),
    dictation: BooleanQuery.optional(),
    encoding: z.string().min(1).optional(),
    endpointing: z.string().min(1).optional(),
    filler_words: BooleanQuery.optional(),
    interim_results: BooleanQuery.optional(),
    keyterm: z.string().min(1).optional(),
    keywords: z.string().min(1).optional(),
    language: z.string().min(1).optional(),
    location_hint: z
      .enum(["wnam", "enam", "sam", "weur", "eeur", "apac", "oc", "afr", "me"])
      .optional(),
    mip_opt_out: BooleanQuery.optional(),
    model: z.string().min(1),
    multichannel: BooleanQuery.optional(),
    numerals: BooleanQuery.optional(),
    profanity_filter: BooleanQuery.optional(),
    punctuate: BooleanQuery.optional(),
    redact: z.string().min(1).optional(),
    replace: z.string().min(1).optional(),
    sample_rate: z.coerce.number().int().positive().optional(),
    search: z.string().min(1).optional(),
    smart_format: BooleanQuery.optional(),
    tag: z.string().min(1).optional(),
    target_streaming_delay_ms: z.coerce.number().int().positive().optional(),
    utterance_end_ms: z.coerce.number().int().positive().optional(),
    vad_events: BooleanQuery.optional(),
    version: z.string().min(1).optional(),
  })
  .strict();

const RealtimeOpenApiQuery = z
  .object({
    audio_format: z.string().optional(),
    channels: z.coerce.number().int().positive().optional(),
    detect_entities: z.enum(["true", "false"]).optional(),
    diarize: z.enum(["true", "false"]).optional(),
    diarize_model: z.enum(["latest", "v1"]).optional(),
    dictation: z.enum(["true", "false"]).optional(),
    encoding: z.string().optional(),
    endpointing: z.string().optional(),
    filler_words: z.enum(["true", "false"]).optional(),
    interim_results: z.enum(["true", "false"]).optional(),
    keyterm: z.string().optional(),
    keywords: z.string().optional(),
    language: z.string().optional(),
    location_hint: z
      .enum(["wnam", "enam", "sam", "weur", "eeur", "apac", "oc", "afr", "me"])
      .optional(),
    mip_opt_out: z.enum(["true", "false"]).optional(),
    model: z.string().min(1).optional(),
    multichannel: z.enum(["true", "false"]).optional(),
    numerals: z.enum(["true", "false"]).optional(),
    profanity_filter: z.enum(["true", "false"]).optional(),
    punctuate: z.enum(["true", "false"]).optional(),
    redact: z.string().optional(),
    replace: z.string().optional(),
    sample_rate: z.coerce.number().int().positive().optional(),
    search: z.string().optional(),
    smart_format: z.enum(["true", "false"]).optional(),
    tag: z.string().optional(),
    target_streaming_delay_ms: z.coerce.number().int().positive().optional(),
    utterance_end_ms: z.coerce.number().int().positive().optional(),
    vad_events: z.enum(["true", "false"]).optional(),
    version: z.string().optional(),
  })
  .strict();

const realtimeRoute = createRoute({
  method: "get",
  path: "/v1/realtime",
  request: {
    query: RealtimeOpenApiQuery,
  },
  responses: {
    101: { description: "WebSocket upgrade accepted." },
    400: { content: JsonErrorContent, description: "Invalid realtime query." },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    426: { description: "Expected WebSocket upgrade." },
  },
  summary: "Open realtime ASR session",
  tags: ["Realtime"],
});

const realtimeSessionResultRoute = createRoute({
  method: "get",
  path: "/v1/realtime/sessions/{session_id}",
  request: {
    params: z.object({ session_id: z.string().min(1) }),
  },
  responses: {
    200: {
      content: {
        "application/json": { schema: RealtimeSessionResultResponse },
      },
      description: "Persisted terminal result for a realtime ASR session.",
    },
    401: { content: JsonErrorContent, description: "Unauthorized." },
    404: { content: JsonErrorContent, description: "Session not found." },
    500: {
      content: JsonErrorContent,
      description: "Stored transcription artifact is unavailable or invalid.",
    },
  },
  summary: "Recover realtime ASR session result",
  tags: ["Realtime"],
});

interface RealtimeSessionRow {
  error: string | null;
  id: string;
  status: "failed" | "succeeded";
  transcript_json_key: string | null;
}

export const registerRealtimeRoutes = (app: App): void => {
  app.openapi(realtimeRoute, async (c) => {
    if (c.req.header("upgrade")?.toLowerCase() !== "websocket") {
      return c.text("expected websocket upgrade", 426);
    }

    const query = RealtimeQuery.safeParse(c.req.query());
    if (!query.success) {
      return c.json(
        { error: "invalid request", issues: query.error.issues },
        400
      );
    }

    let modelRoute: RealtimeAsrModelEntry;
    try {
      modelRoute = resolveRealtimeAsrModel(query.data.model);
    } catch (error) {
      return c.json(
        { error: error instanceof Error ? error.message : String(error) },
        400
      );
    }
    const language = resolveRealtimeLanguage(modelRoute, query.data.language);
    if (language && !modelRoute.supportedLanguages.includes(language)) {
      return c.json(
        {
          error: `language '${language}' is not supported by ${query.data.model}`,
        },
        400
      );
    }

    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }

    const sessionId = newId("rt");
    const id = c.env.REALTIME_SESSIONS.idFromName(sessionId);
    const stub = c.env.REALTIME_SESSIONS.get(
      id,
      query.data.location_hint
        ? { locationHint: query.data.location_hint }
        : undefined
    );
    const url = new URL(c.req.url);
    const headers = new Headers(c.req.raw.headers);
    headers.set("x-realtime-session-id", sessionId);
    headers.set(
      "x-realtime-config",
      JSON.stringify({
        channels: query.data.channels,
        clientId: auth.credentialId,
        credentialId: auth.credentialId,
        deepgram: {
          detectEntities: query.data.detect_entities,
          diarize: query.data.diarize,
          diarizeModel: query.data.diarize_model,
          dictation: query.data.dictation,
          endpointing: query.data.endpointing,
          fillerWords: query.data.filler_words,
          interimResults: query.data.interim_results,
          keyterm: url.searchParams.getAll("keyterm"),
          keywords: url.searchParams.getAll("keywords"),
          mipOptOut: query.data.mip_opt_out,
          multichannel: query.data.multichannel,
          numerals: query.data.numerals,
          profanityFilter: query.data.profanity_filter,
          punctuate: query.data.punctuate,
          redact: url.searchParams.getAll("redact"),
          replace: url.searchParams.getAll("replace"),
          search: url.searchParams.getAll("search"),
          smartFormat: query.data.smart_format,
          tag: url.searchParams.getAll("tag"),
          utteranceEndMs: query.data.utterance_end_ms,
          vadEvents: query.data.vad_events,
          version: query.data.version,
        },
        encoding: query.data.encoding ?? query.data.audio_format,
        executionModel: modelRoute.executionModel,
        executionProvider: modelRoute.executionProvider,
        language,
        model: query.data.model,
        provider: modelRoute.provider,
        sampleRate: query.data.sample_rate,
        sessionId,
        targetStreamingDelayMs: query.data.target_streaming_delay_ms,
        upstreamModel: modelRoute.upstreamModel,
        userId: auth.userId,
      })
    );

    return stub.fetch(new Request(c.req.raw, { headers }));
  });

  app.openapi(realtimeSessionResultRoute, async (c) => {
    const auth = await authenticateCredential(
      c.env,
      c.req.header("authorization")
    );
    if (!auth) {
      return c.json({ error: "unauthorized" }, 401);
    }
    const row = await c.env.DB.prepare(
      `SELECT id, status, error, transcript_json_key
         FROM realtime_sessions
        WHERE id = ? AND owner_user_id = ? AND ended_at IS NOT NULL`
    )
      .bind(c.req.valid("param").session_id, auth.userId)
      .first<RealtimeSessionRow>();
    if (!row) {
      return c.json({ error: "realtime session not found" }, 404);
    }
    if (!row.transcript_json_key) {
      return c.json({ error: "transcription artifact is unavailable" }, 500);
    }
    const stored = await c.env.ARTIFACTS.get(row.transcript_json_key);
    if (!stored) {
      return c.json({ error: "transcription artifact is unavailable" }, 500);
    }
    const artifact = TranscriptionArtifactSchema.safeParse(await stored.json());
    if (!artifact.success) {
      return c.json({ error: "stored transcription artifact is invalid" }, 500);
    }
    return c.json(
      terminalSessionEvent(
        {
          error: row.error,
          result: artifact.data,
          sessionId: row.id,
          status: row.status,
        },
        0
      ),
      200
    );
  });
};
