import type {
  DictationOutcome,
  DictationPlan,
} from "@/features/dictation/dictation-types";
import {
  DictationWorkflow,
  type RealtimeTransportCallbacks,
} from "@/features/dictation/dictation-workflow";
import type { RealtimeProtocolEvent } from "@/features/dictation/realtime-protocol";

const plan: DictationPlan = {
  credential: "test-session",
  entryPoint: "app",
  executor: {
    kind: "cloud-realtime",
    model: "mistral-voxtral-realtime",
    provider: "mistral",
  },
  mode: {
    asrModelId: "voxtral",
    description: "Voice",
    iconKey: "waveform",
    id: "mode_voice",
    identifySpeakers: false,
    language: "en",
    name: "Voice to Text",
    presetKind: "voice",
    processingInstructions: null,
    processingModelId: null,
    realtimeModel: "mistral-voxtral-realtime",
  },
  requestId: "request_1",
};

function event(
  type: string,
  sequence: number,
  extra: Record<string, unknown> = {},
) {
  return JSON.stringify({
    protocol_version: 1,
    sequence,
    session_id: "rt_1",
    type,
    ...extra,
  });
}

function makeHarness(
  persist: jest.Mock<Promise<void>, [DictationOutcome]> = jest.fn(
    async (_outcome: DictationOutcome) => undefined,
  ),
  recover: (
    plan: DictationPlan,
    sessionId: string,
    credential: string,
  ) => Promise<RealtimeProtocolEvent> = async () => {
    throw new Error("not needed");
  },
  deliver: jest.Mock<Promise<void>, [DictationOutcome, string]> = jest.fn(
    async (_outcome: DictationOutcome, _text: string) => undefined,
  ),
  transcribeBatch = jest.fn(async () => ({
    schema_version: 2 as const,
    text: "Batch result.",
  })),
) {
  let callbacks: RealtimeTransportCallbacks | null = null;
  const close = jest.fn();
  const finalize = jest.fn();
  const sendAudio = jest.fn();
  const snapshots: string[] = [];
  const workflow = new DictationWorkflow({
    connectionTimeoutMs: 60_000,
    createId: () => "dictation_1",
    createTransport: (_plan, nextCallbacks) => {
      callbacks = nextCallbacks;
      return { close, finalize, sendAudio };
    },
    deliver,
    finalizationTimeoutMs: 15_000,
    now: (() => {
      const values = [
        new Date("2026-07-14T10:00:00.000Z"),
        new Date("2026-07-14T10:00:03.250Z"),
      ];
      return () => values.shift() ?? values.at(-1)!;
    })(),
    onChange: (snapshot) => snapshots.push(snapshot.stage),
    persist,
    process: async () => null,
    recover,
    transcribeBatch,
  });
  return {
    callbacks: () => callbacks!,
    close,
    deliver,
    finalize,
    persist,
    sendAudio,
    snapshots,
    transcribeBatch,
    workflow,
  };
}

async function settle() {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
}

describe("DictationWorkflow", () => {
  it("moves through realtime capture, persists and delivers, then clears the recording surface", async () => {
    const harness = makeHarness();
    harness.workflow.ready();
    expect(harness.workflow.start(plan)).toBe(true);
    expect(harness.workflow.current.stage).toBe("connecting");

    harness.workflow.receiveAudio(new Uint8Array([1, 2]).buffer);
    harness.callbacks().onOpen();
    expect(harness.workflow.current.stage).toBe("listening");
    expect(harness.sendAudio).toHaveBeenCalledTimes(1);

    harness
      .callbacks()
      .onMessage(
        event("session.started", 1, { language: "en", model: "voxtral" }),
      );
    harness
      .callbacks()
      .onMessage(event("transcript.delta", 2, { text: "Hel" }));
    expect(harness.workflow.current.visibleText).toBe("Hel");
    harness
      .callbacks()
      .onMessage(event("transcript.interim", 3, { text: "Hello" }));
    expect(harness.workflow.current.visibleText).toBe("Hello");

    harness.workflow.stop();
    expect(harness.workflow.current).toMatchObject({
      stage: "finalizing",
      visibleText: "Hello",
    });
    expect(harness.finalize).toHaveBeenCalledTimes(1);

    harness.callbacks().onMessage(
      event("session.completed", 4, {
        result: {
          language: { detected: "en", requested: "en" },
          schema_version: 2,
          text: "Hello world.",
        },
        status: "succeeded",
      }),
    );
    await settle();

    expect(harness.workflow.current).toMatchObject({
      finalText: "",
      resultId: "dictation_1",
      stage: "result",
      visibleText: "",
    });
    expect(harness.deliver).toHaveBeenCalledWith(
      expect.objectContaining({ resultId: "dictation_1" }),
      "Hello world.",
    );
    expect(harness.persist).toHaveBeenCalledWith(
      expect.objectContaining({
        durationMs: 3_250,
        entryPoint: "app",
        requestId: "request_1",
        resultId: "dictation_1",
        status: "succeeded",
      }),
    );
    expect(harness.snapshots).toEqual(
      expect.arrayContaining([
        "ready",
        "connecting",
        "listening",
        "finalizing",
        "result",
      ]),
    );
    expect(harness.workflow.acknowledgeResult()).toBe(true);
    expect(harness.workflow.current).toMatchObject({
      resultId: null,
      stage: "ready",
      visibleText: "",
    });
  });

  it("runs a genuine batch executor without opening a realtime transport", async () => {
    const harness = makeHarness();
    const batchPlan: DictationPlan = {
      ...plan,
      executor: {
        kind: "cloud-batch",
        model: "voxtral-mini-latest",
        provider: "mistral",
      },
    };
    harness.workflow.ready();
    expect(harness.workflow.start(batchPlan)).toBe(true);
    expect(harness.workflow.current.stage).toBe("listening");
    expect(harness.callbacks()).toBeNull();

    const audio = new Uint8Array([1, 2, 3]).buffer;
    harness.workflow.receiveAudio(audio);
    expect(harness.workflow.stop()).toBe(true);
    await settle();

    expect(harness.transcribeBatch).toHaveBeenCalledWith(batchPlan, [audio]);
    expect(harness.persist).toHaveBeenCalledWith(
      expect.objectContaining({ status: "succeeded" }),
    );
    expect(harness.deliver).toHaveBeenCalledWith(
      expect.anything(),
      "Batch result.",
    );
    expect(harness.workflow.current).toMatchObject({
      finalText: "",
      stage: "result",
      visibleText: "",
    });
  });

  it("cancels to ready without persisting", () => {
    const harness = makeHarness();
    harness.workflow.ready();
    harness.workflow.start(plan);
    expect(harness.workflow.cancel()).toBe(true);
    expect(harness.workflow.current.stage).toBe("ready");
    expect(harness.persist).not.toHaveBeenCalled();
    expect(harness.close).toHaveBeenCalled();
  });

  it("exposes explicit permission and transport failures", () => {
    const permission = makeHarness();
    permission.workflow.failBeforeStart({
      action: "open-settings",
      code: "microphone_denied",
      message: "Microphone access is required.",
      retryable: true,
    });
    expect(permission.workflow.current).toMatchObject({
      error: { action: "open-settings", code: "microphone_denied" },
      stage: "error",
    });

    const socket = makeHarness();
    socket.workflow.ready();
    socket.workflow.start(plan);
    socket.callbacks().onError("Socket failed.");
    expect(socket.workflow.current).toMatchObject({
      error: { action: "reconnect", code: "interrupted_input" },
      stage: "error",
    });
  });

  it("times out a connection that never opens", () => {
    jest.useFakeTimers();
    try {
      const harness = makeHarness();
      harness.workflow.ready();
      harness.workflow.start(plan);

      jest.advanceTimersByTime(60_000);

      expect(harness.workflow.current).toMatchObject({
        error: { action: "reconnect", code: "connection_timeout" },
        stage: "error",
      });
      expect(harness.close).toHaveBeenCalled();
    } finally {
      jest.useRealTimers();
    }
  });

  it("recovers a terminal result when finalization stops producing events", async () => {
    jest.useFakeTimers();
    try {
      const recover = jest.fn(async (): Promise<RealtimeProtocolEvent> => ({
        result: {
          schema_version: 2,
          text: "Recovered final result.",
        },
        sequence: 4,
        sessionId: "rt_1",
        type: "session.completed",
      }));
      const harness = makeHarness(undefined, recover);
      harness.workflow.ready();
      harness.workflow.start(plan);
      harness.callbacks().onOpen();
      harness.workflow.receiveAudio(new Uint8Array([1, 2]).buffer);
      harness
        .callbacks()
        .onMessage(
          event("session.started", 1, { language: "en", model: "voxtral" }),
        );
      harness.workflow.stop();

      jest.advanceTimersByTime(15_000);
      await settle();

      expect(recover).toHaveBeenCalledWith(plan, "rt_1", "test-session");
      expect(harness.persist).toHaveBeenCalledWith(
        expect.objectContaining({
          requestId: "request_1",
          status: "succeeded",
        }),
      );
      expect(harness.workflow.current).toMatchObject({
        finalText: "",
        stage: "result",
        visibleText: "",
      });
    } finally {
      jest.useRealTimers();
    }
  });

  it("persists the provider artifact before surfacing a provider error", async () => {
    const harness = makeHarness();
    harness.workflow.ready();
    harness.workflow.start(plan);
    harness.callbacks().onOpen();
    harness
      .callbacks()
      .onMessage(
        event("session.started", 1, { language: "en", model: "voxtral" }),
      );
    harness.callbacks().onMessage(
      event("session.failed", 2, {
        error: {
          code: "provider_error",
          message: "Provider unavailable.",
          retryable: true,
        },
        result: { schema_version: 2, text: "Recoverable partial" },
        status: "failed",
      }),
    );
    await settle();

    expect(harness.persist).toHaveBeenCalledWith(
      expect.objectContaining({
        error: {
          code: "provider_error",
          message: "Provider unavailable.",
        },
        status: "failed",
      }),
    );
    expect(harness.workflow.current).toMatchObject({
      error: { code: "provider_error" },
      stage: "error",
      visibleText: "Recoverable partial",
    });
  });

  it("normalizes the provider's empty-artifact terminal response to no speech", async () => {
    const harness = makeHarness();
    harness.workflow.ready();
    harness.workflow.start(plan);
    harness.callbacks().onOpen();
    harness
      .callbacks()
      .onMessage(
        event("session.started", 1, { language: "en", model: "voxtral" }),
      );
    harness.callbacks().onMessage(
      event("session.failed", 2, {
        error: {
          code: "provider_error",
          message: "No transcript generated.",
          retryable: true,
        },
        result: { schema_version: 2, text: "" },
        status: "failed",
      }),
    );
    await settle();

    expect(harness.persist).toHaveBeenCalledWith(
      expect.objectContaining({ error: null, status: "no_speech" }),
    );
    expect(harness.workflow.current).toMatchObject({
      error: null,
      finalText: "",
      stage: "result",
      visibleText: "",
    });
  });

  it("keeps a failed save available for retry", async () => {
    const persist = jest
      .fn<Promise<void>, [DictationOutcome]>()
      .mockRejectedValueOnce(new Error("disk full"))
      .mockResolvedValueOnce(undefined);
    const harness = makeHarness(persist);
    harness.workflow.ready();
    harness.workflow.start(plan);
    harness.callbacks().onOpen();
    harness
      .callbacks()
      .onMessage(
        event("session.started", 1, { language: "en", model: "voxtral" }),
      );
    harness.callbacks().onMessage(
      event("session.completed", 2, {
        result: { schema_version: 2, text: "Saved after retry." },
        status: "succeeded",
      }),
    );
    await settle();
    expect(harness.workflow.current).toMatchObject({
      error: { action: "retry-save", code: "persistence_failure" },
      stage: "error",
      visibleText: "Saved after retry.",
    });

    await expect(harness.workflow.retrySave()).resolves.toBe(true);
    expect(harness.workflow.current.stage).toBe("result");
    expect(persist).toHaveBeenCalledTimes(2);
  });

  it("keeps a failed delivery available for retry after persistence succeeds", async () => {
    const deliver = jest
      .fn<Promise<void>, [DictationOutcome, string]>()
      .mockRejectedValueOnce(new Error("clipboard unavailable"))
      .mockResolvedValueOnce(undefined);
    const harness = makeHarness(undefined, undefined, deliver);
    harness.workflow.ready();
    harness.workflow.start(plan);
    harness.callbacks().onOpen();
    harness
      .callbacks()
      .onMessage(
        event("session.started", 1, { language: "en", model: "voxtral" }),
      );
    harness.callbacks().onMessage(
      event("session.completed", 2, {
        result: { schema_version: 2, text: "Deliver after retry." },
        status: "succeeded",
      }),
    );
    await settle();

    expect(harness.persist).toHaveBeenCalledTimes(1);
    expect(harness.workflow.current).toMatchObject({
      error: { action: "retry-delivery", code: "delivery_failure" },
      stage: "error",
    });
    await expect(harness.workflow.retryDelivery()).resolves.toBe(true);
    expect(deliver).toHaveBeenCalledTimes(2);
    expect(harness.workflow.current.stage).toBe("result");
  });

  it("cancels cleanly when stopped before any audio was captured", () => {
    const harness = makeHarness();
    harness.workflow.ready();
    expect(harness.workflow.start(plan)).toBe(true);
    expect(harness.workflow.current.stage).toBe("connecting");

    expect(harness.workflow.stop()).toBe(true);

    expect(harness.workflow.current.stage).toBe("ready");
    expect(harness.workflow.current.error).toBeNull();
    expect(harness.finalize).not.toHaveBeenCalled();
    expect(harness.persist).not.toHaveBeenCalled();
    expect(harness.close).toHaveBeenCalled();
  });

  it("finalizes a stop during connecting once the socket opens instead of losing the take", async () => {
    const harness = makeHarness();
    harness.workflow.ready();
    expect(harness.workflow.start(plan)).toBe(true);
    expect(harness.workflow.current.stage).toBe("connecting");

    harness.workflow.receiveAudio(new Uint8Array([1, 2]).buffer);
    expect(harness.workflow.stop()).toBe(true);
    expect(harness.workflow.current.stage).toBe("finalizing");
    // The handshake has not completed, so nothing is finalized yet.
    expect(harness.finalize).not.toHaveBeenCalled();

    harness.callbacks().onOpen();
    expect(harness.sendAudio).toHaveBeenCalledTimes(1);
    expect(harness.finalize).toHaveBeenCalledTimes(1);

    harness
      .callbacks()
      .onMessage(
        event("session.started", 1, { language: "en", model: "voxtral" }),
      );
    harness.callbacks().onMessage(
      event("session.completed", 2, {
        result: {
          language: { detected: "en", requested: "en" },
          schema_version: 2,
          text: "Quick stop.",
        },
        status: "succeeded",
      }),
    );
    await settle();
    expect(harness.workflow.current.stage).toBe("result");
    expect(harness.persist).toHaveBeenCalledWith(
      expect.objectContaining({ status: "succeeded" }),
    );
  });

  it("delivers the raw transcript when text processing fails", async () => {
    const persist = jest.fn(async (_outcome: DictationOutcome) => undefined);
    const deliver = jest.fn(
      async (_outcome: DictationOutcome, _text: string) => undefined,
    );
    let callbacks: RealtimeTransportCallbacks | null = null;
    const workflow = new DictationWorkflow({
      createTransport: (_plan, nextCallbacks) => {
        callbacks = nextCallbacks;
        return { close: jest.fn(), finalize: jest.fn(), sendAudio: jest.fn() };
      },
      deliver,
      onChange: () => undefined,
      persist,
      process: async () => {
        throw new Error("Rate limited.");
      },
      recover: async () => {
        throw new Error("not needed");
      },
      transcribeBatch: async () => ({ schema_version: 2 as const, text: "" }),
    });

    workflow.ready();
    expect(workflow.start(plan)).toBe(true);
    callbacks!.onOpen();
    callbacks!.onMessage(event("session.started", 1, {}));
    workflow.stop();
    callbacks!.onMessage(
      event("session.completed", 2, {
        result: {
          language: { detected: "en", requested: "en" },
          schema_version: 2,
          text: "Raw words survive.",
        },
        status: "succeeded",
      }),
    );
    await settle();

    expect(workflow.current.stage).toBe("result");
    expect(persist).toHaveBeenCalledWith(
      expect.objectContaining({
        error: null,
        status: "succeeded",
      }),
    );
    const persisted = persist.mock.calls[0]![0]!;
    expect(persisted.artifacts.map((artifact) => artifact.kind)).toEqual([
      "raw",
    ]);
    expect(deliver).toHaveBeenCalledWith(
      expect.objectContaining({ status: "succeeded" }),
      "Raw words survive.",
    );
  });

  it("abandons completion cleanly when the session is cancelled during processing", async () => {
    let resolveProcess: (value: string | null) => void = () => undefined;
    const persist = jest.fn(async (_outcome: DictationOutcome) => undefined);
    const deliver = jest.fn(
      async (_outcome: DictationOutcome, _text: string) => undefined,
    );
    let callbacks: RealtimeTransportCallbacks | null = null;
    const workflow = new DictationWorkflow({
      createTransport: (_plan, nextCallbacks) => {
        callbacks = nextCallbacks;
        return { close: jest.fn(), finalize: jest.fn(), sendAudio: jest.fn() };
      },
      deliver,
      onChange: () => undefined,
      persist,
      process: () =>
        new Promise<string | null>((resolve) => {
          resolveProcess = resolve;
        }),
      recover: async () => {
        throw new Error("not needed");
      },
      transcribeBatch: async () => ({ schema_version: 2 as const, text: "" }),
    });

    workflow.ready();
    expect(workflow.start(plan)).toBe(true);
    callbacks!.onOpen();
    callbacks!.onMessage(event("session.started", 1, {}));
    workflow.stop();
    callbacks!.onMessage(
      event("session.completed", 2, {
        result: {
          language: { detected: "en", requested: "en" },
          schema_version: 2,
          text: "Hello world.",
        },
        status: "succeeded",
      }),
    );
    await settle();

    // Text processing is still pending; the user tears the session down.
    expect(workflow.cancel()).toBe(true);
    expect(workflow.current.stage).toBe("ready");

    resolveProcess("Processed text.");
    await settle();

    expect(workflow.current.stage).toBe("ready");
    expect(persist).not.toHaveBeenCalled();
    expect(deliver).not.toHaveBeenCalled();
  });
});
