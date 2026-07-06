import type { OpenAPIHono } from "@hono/zod-openapi";
import { createRoute, z } from "@hono/zod-openapi";

import {
  type RealtimeModelRoute,
  realtimeModelRoute,
} from "../ai/model-routes";
import type { Env } from "../bindings";
import { newId } from "../lib/ids";
import { JsonErrorContent } from "./openapi-schemas";

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

const realtimeRoute = createRoute({
  method: "get",
  path: "/v1/realtime",
  request: {
    query: z.object({
      audio_format: z.string().optional(),
      encoding: z.string().optional(),
      language: z.string().optional(),
      model: z.string().optional(),
      sample_rate: z.coerce.number().int().positive().optional(),
    }),
  },
  responses: {
    101: { description: "WebSocket upgrade accepted." },
    400: { content: JsonErrorContent, description: "Invalid realtime query." },
    426: { description: "Expected WebSocket upgrade." },
  },
  summary: "Open realtime ASR session",
  tags: ["Realtime"],
});

export const registerRealtimeRoutes = (app: App): void => {
  app.openapi(realtimeRoute, (c) => {
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

    let modelRoute: RealtimeModelRoute;
    try {
      modelRoute = realtimeModelRoute(query.data.model);
    } catch (error) {
      return c.json(
        { error: error instanceof Error ? error.message : String(error) },
        400
      );
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
        clientId: c.req.header("x-timbervox-client-id") ?? null,
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
        language: query.data.language,
        model: query.data.model,
        provider: modelRoute.provider,
        sampleRate: query.data.sample_rate,
        sessionId,
        targetStreamingDelayMs: query.data.target_streaming_delay_ms,
        upstreamModel: modelRoute.upstreamModel,
      })
    );

    return stub.fetch(new Request(c.req.raw, { headers }));
  });
};
