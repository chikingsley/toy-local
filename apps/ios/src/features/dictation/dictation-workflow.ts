import type {
  DictationFailure,
  DictationOutcome,
  DictationPlan,
  DictationWorkflowSnapshot,
  PersistedArtifact,
  TranscriptionArtifact,
} from "@/features/dictation/dictation-types";
import {
  parseRealtimeEvent,
  RealtimeProtocolError,
  type RealtimeProtocolEvent,
} from "@/features/dictation/realtime-protocol";
import {
  EMPTY_STREAMING_TRANSCRIPT,
  reduceStreamingTranscript,
  type StreamingTranscript,
  visibleStreamingTranscript,
} from "@/features/dictation/streaming-transcript";

type RealtimeTransportCallbacks = {
  onClose: () => void;
  onError: (message: string) => void;
  onMessage: (raw: string) => void;
  onOpen: () => void;
};

export type RealtimeTransport = {
  close: () => void;
  finalize: () => void;
  sendAudio: (audio: ArrayBuffer) => void;
};

type WorkflowDependencies = {
  connectionTimeoutMs?: number;
  createId?: (prefix: "artifact" | "dictation") => string;
  finalizationTimeoutMs?: number;
  createTransport: (
    plan: DictationPlan,
    callbacks: RealtimeTransportCallbacks,
  ) => RealtimeTransport;
  deliver: (outcome: DictationOutcome, text: string) => Promise<void>;
  now?: () => Date;
  onChange: (snapshot: DictationWorkflowSnapshot) => void;
  persist: (outcome: DictationOutcome) => Promise<void>;
  process: (plan: DictationPlan, transcript: string) => Promise<string | null>;
  recover: (
    plan: DictationPlan,
    sessionId: string,
    credential: string,
  ) => Promise<RealtimeProtocolEvent>;
  transcribeBatch: (
    plan: DictationPlan,
    audioChunks: ArrayBuffer[],
  ) => Promise<TranscriptionArtifact>;
};

const INITIAL_SNAPSHOT: DictationWorkflowSnapshot = {
  error: null,
  finalText: "",
  requestId: null,
  resultHadText: false,
  resultId: null,
  sessionId: null,
  stage: "idle",
  visibleText: "",
};

class DictationWorkflow {
  private readonly dependencies: Required<
    Pick<
      WorkflowDependencies,
      "connectionTimeoutMs" | "createId" | "finalizationTimeoutMs" | "now"
    >
  > &
    Omit<
      WorkflowDependencies,
      "connectionTimeoutMs" | "createId" | "finalizationTimeoutMs" | "now"
    >;
  private snapshot: DictationWorkflowSnapshot = INITIAL_SNAPSHOT;
  private transcript: StreamingTranscript = EMPTY_STREAMING_TRANSCRIPT;
  private transport: RealtimeTransport | null = null;
  private plan: DictationPlan | null = null;
  private audioChunks: ArrayBuffer[] = [];
  private queuedAudio: ArrayBuffer[] = [];
  private startedAt: Date | null = null;
  private lastSequence = -1;
  private connectionTimer: ReturnType<typeof setTimeout> | null = null;
  private finalizationTimer: ReturnType<typeof setTimeout> | null = null;
  private pendingOutcome: DictationOutcome | null = null;
  private pendingDelivery: { outcome: DictationOutcome; text: string } | null =
    null;
  private recoveryInFlight = false;
  private terminal = false;
  // Bumped by start/cancel/idle so async completion work can detect that the
  // session it belongs to was torn down while it awaited.
  private generation = 0;
  // Set when the user stops while the transport is still handshaking; the
  // queued audio flushes and finalizes as soon as the socket opens instead of
  // closing an un-opened connection and losing the take.
  private finalizeWhenOpen = false;

  constructor(dependencies: WorkflowDependencies) {
    this.dependencies = {
      connectionTimeoutMs: dependencies.connectionTimeoutMs ?? 10_000,
      createId: dependencies.createId ?? createIdentifier,
      finalizationTimeoutMs: dependencies.finalizationTimeoutMs ?? 15_000,
      now: dependencies.now ?? (() => new Date()),
      createTransport: dependencies.createTransport,
      deliver: dependencies.deliver,
      onChange: dependencies.onChange,
      persist: dependencies.persist,
      process: dependencies.process,
      recover: dependencies.recover,
      transcribeBatch: dependencies.transcribeBatch,
    };
  }

  get current() {
    return this.snapshot;
  }

  ready() {
    if (this.isCapturing()) return;
    this.update({ error: null, stage: "ready" });
  }

  idle() {
    this.generation += 1;
    this.finalizeWhenOpen = false;
    this.clearConnectionTimer();
    this.clearFinalizationTimer();
    this.transport?.close();
    this.transport = null;
    this.plan = null;
    this.audioChunks = [];
    this.queuedAudio = [];
    this.pendingDelivery = null;
    this.update({ ...INITIAL_SNAPSHOT });
  }

  acknowledgeResult() {
    if (this.snapshot.stage !== "result") return false;
    this.plan = null;
    this.audioChunks = [];
    this.queuedAudio = [];
    this.transcript = EMPTY_STREAMING_TRANSCRIPT;
    this.update({
      error: null,
      finalText: "",
      requestId: null,
      resultHadText: false,
      resultId: null,
      sessionId: null,
      stage: "ready",
      visibleText: "",
    });
    return true;
  }

  failBeforeStart(failure: DictationFailure) {
    if (this.isCapturing()) return;
    this.update({ error: failure, stage: "error" });
  }

  start(plan: DictationPlan) {
    if (this.isCapturing()) return false;
    this.generation += 1;
    this.finalizeWhenOpen = false;
    this.clearConnectionTimer();
    this.clearFinalizationTimer();
    this.transport?.close();
    this.plan = plan;
    this.transcript = EMPTY_STREAMING_TRANSCRIPT;
    this.audioChunks = [];
    this.queuedAudio = [];
    this.startedAt = this.dependencies.now();
    this.lastSequence = -1;
    this.pendingOutcome = null;
    this.pendingDelivery = null;
    this.recoveryInFlight = false;
    this.terminal = false;
    this.update({
      error: null,
      finalText: "",
      requestId: plan.requestId,
      resultHadText: false,
      resultId: null,
      sessionId: null,
      stage: isRealtimePlan(plan) ? "connecting" : "listening",
      visibleText: "",
    });
    if (!isRealtimePlan(plan)) return true;
    this.transport = this.dependencies.createTransport(plan, {
      onClose: () => void this.handleClose(),
      onError: (message) => this.handleTransportError(message),
      onMessage: (raw) => void this.handleRawEvent(raw),
      onOpen: () => this.handleOpen(),
    });
    this.connectionTimer = setTimeout(() => {
      if (this.snapshot.stage !== "connecting") return;
      this.transport?.close();
      this.transport = null;
      this.fail({
        action: "reconnect",
        code: "connection_timeout",
        message: "TimberVox could not connect in time.",
        retryable: true,
      });
    }, this.dependencies.connectionTimeoutMs);
    return true;
  }

  receiveAudio(audio: ArrayBuffer) {
    if (!this.isCapturing()) return;
    const copy = audio.slice(0);
    this.audioChunks.push(copy);
    if (this.snapshot.stage === "listening" && isRealtimePlan(this.plan)) {
      this.transport?.sendAudio(copy);
    } else if (this.snapshot.stage === "connecting") {
      this.queuedAudio.push(copy);
    }
  }

  stop() {
    if (
      this.snapshot.stage !== "connecting" &&
      this.snapshot.stage !== "listening"
    ) {
      return false;
    }
    if (this.audioChunks.length === 0) {
      // Nothing was captured before the stop, so there is no dictation to
      // finalize; an empty flush would only produce a provider error.
      this.cancel();
      return true;
    }
    const stoppedWhileConnecting = this.snapshot.stage === "connecting";
    this.clearConnectionTimer();
    this.update({ stage: "finalizing" });
    if (this.plan && !isRealtimePlan(this.plan)) {
      void this.completeBatch();
      return true;
    }
    if (stoppedWhileConnecting && this.transport) {
      this.finalizeWhenOpen = true;
    } else {
      this.transport?.finalize();
    }
    this.finalizationTimer = setTimeout(() => {
      if (this.snapshot.stage !== "finalizing" || this.terminal) return;
      const transport = this.transport;
      this.transport = null;
      transport?.close();
      void this.recoverTerminal();
    }, this.dependencies.finalizationTimeoutMs);
    return true;
  }

  cancel() {
    if (!this.isCapturing()) return false;
    this.generation += 1;
    this.finalizeWhenOpen = false;
    this.clearConnectionTimer();
    this.clearFinalizationTimer();
    this.transport?.close();
    this.transport = null;
    this.plan = null;
    this.audioChunks = [];
    this.queuedAudio = [];
    this.transcript = EMPTY_STREAMING_TRANSCRIPT;
    this.terminal = true;
    this.recoveryInFlight = false;
    this.pendingDelivery = null;
    this.update({
      error: null,
      finalText: "",
      requestId: null,
      resultHadText: false,
      resultId: null,
      sessionId: null,
      stage: "ready",
      visibleText: "",
    });
    return true;
  }

  async retrySave() {
    if (!this.pendingOutcome) return false;
    const generation = this.generation;
    try {
      await this.dependencies.persist(this.pendingOutcome);
      const outcome = this.pendingOutcome;
      this.pendingOutcome = null;
      if (this.generation !== generation) return true;
      await this.finishPersistedOutcome(
        outcome,
        displayedText(outcome),
        generation,
      );
      return true;
    } catch {
      if (this.generation !== generation) return false;
      this.fail(persistenceFailure());
      return false;
    }
  }

  async retryDelivery() {
    if (!this.pendingDelivery) return false;
    const delivery = this.pendingDelivery;
    const generation = this.generation;
    try {
      await this.dependencies.deliver(delivery.outcome, delivery.text);
      this.pendingDelivery = null;
      if (this.generation !== generation) return true;
      this.update({
        error: null,
        finalText: "",
        resultHadText: Boolean(delivery.text.trim()),
        stage: "result",
        visibleText: "",
      });
      return true;
    } catch {
      if (this.generation !== generation) return false;
      this.fail(deliveryFailure());
      return false;
    }
  }

  private handleOpen() {
    if (this.snapshot.stage === "connecting") {
      this.clearConnectionTimer();
      this.update({ stage: "listening" });
      for (const audio of this.queuedAudio) this.transport?.sendAudio(audio);
      this.queuedAudio = [];
      return;
    }
    if (this.snapshot.stage === "finalizing" && this.finalizeWhenOpen) {
      this.finalizeWhenOpen = false;
      for (const audio of this.queuedAudio) this.transport?.sendAudio(audio);
      this.queuedAudio = [];
      this.transport?.finalize();
    }
  }

  private async handleRawEvent(raw: string) {
    let event: RealtimeProtocolEvent | null;
    try {
      event = parseRealtimeEvent(raw);
    } catch (error) {
      this.transport?.close();
      this.transport = null;
      this.fail({
        action: "reconnect",
        code: "unsupported_protocol",
        message:
          error instanceof RealtimeProtocolError
            ? error.message
            : "The realtime response could not be read.",
        retryable: true,
      });
      return;
    }
    if (!event || this.terminal) return;
    if (event.sequence <= this.lastSequence) return;
    this.lastSequence = event.sequence;
    if (
      this.snapshot.sessionId &&
      event.sessionId !== this.snapshot.sessionId
    ) {
      return;
    }
    if (event.type === "session.started") {
      this.update({ sessionId: event.sessionId });
      return;
    }
    if (event.type === "transcript.delta") {
      this.applyTranscript({ text: event.text, type: "delta" });
      return;
    }
    if (event.type === "transcript.interim") {
      this.applyTranscript({ text: event.text, type: "interim" });
      return;
    }
    if (event.type === "transcript.committed") {
      this.applyTranscript({ text: event.text, type: "committed" });
      return;
    }
    if (event.type === "session.completed" || event.type === "session.failed") {
      await this.complete(event);
    }
  }

  private applyTranscript(event: {
    text: string;
    type: "committed" | "delta" | "interim";
  }) {
    this.transcript = reduceStreamingTranscript(this.transcript, event);
    this.update({ visibleText: visibleStreamingTranscript(this.transcript) });
  }

  private async complete(
    event: Extract<
      RealtimeProtocolEvent,
      { type: "session.completed" | "session.failed" }
    >,
  ) {
    const plan = this.plan;
    const startedAt = this.startedAt;
    if (!plan || !startedAt || this.terminal) return;
    const generation = this.generation;
    this.terminal = true;
    this.finalizeWhenOpen = false;
    this.clearConnectionTimer();
    this.clearFinalizationTimer();
    this.transport?.close();
    this.transport = null;
    if (this.snapshot.stage !== "finalizing") {
      this.update({ stage: "finalizing" });
    }

    const finalText = event.result.text;
    this.transcript = reduceStreamingTranscript(this.transcript, {
      text: finalText,
      type: "final",
    });
    const resultId = this.dependencies.createId("dictation");
    this.update({
      finalText,
      resultId,
      sessionId: event.sessionId,
      visibleText: finalText,
    });

    const endedAt = this.dependencies.now();
    const artifacts: PersistedArtifact[] = [
      rawArtifact(resultId, event.result, plan.mode.asrModelId),
    ];
    const audioChunks = this.audioChunks;
    let displayedText = finalText;
    let processingError: Error | null = null;
    if (event.type === "session.completed" && finalText.trim()) {
      try {
        const processed = await this.dependencies.process(plan, finalText);
        if (this.generation !== generation) return;
        if (processed?.trim()) {
          displayedText = processed.trim();
          artifacts.push({
            id: `${resultId}_processed`,
            kind: "processed",
            modelId: plan.mode.processingModelId,
            payload: null,
            text: displayedText,
            timing: null,
          });
          this.update({ finalText: displayedText, visibleText: displayedText });
        }
      } catch (error) {
        if (this.generation !== generation) return;
        processingError =
          error instanceof Error ? error : new Error("Text processing failed.");
      }
    }

    const noSpeech = isNoSpeechEvent(event);
    const providerFailed = event.type === "session.failed" && !noSpeech;
    // A text-processing failure does not fail the dictation: the canonical
    // raw transcript is persisted and delivered, and History's reprocess
    // action can redo the processing step later.
    const failed = providerFailed;
    const outcome: DictationOutcome = {
      artifacts,
      audioChunks,
      createdAt: startedAt.toISOString(),
      durationMs: Math.max(0, endedAt.getTime() - startedAt.getTime()),
      endedAt: endedAt.toISOString(),
      entryPoint: plan.entryPoint,
      error: failed
        ? {
            code: event.error.code,
            message: event.error.message ?? "Dictation failed.",
          }
        : null,
      language: artifactLanguage(event.result) ?? plan.mode.language,
      mode: plan.mode,
      requestId: plan.requestId,
      resultId,
      startedAt: startedAt.toISOString(),
      status: failed
        ? "failed"
        : displayedText.trim()
          ? "succeeded"
          : "no_speech",
    };
    this.pendingOutcome = outcome;
    try {
      await this.dependencies.persist(outcome);
      this.pendingOutcome = null;
      if (this.generation !== generation) return;
    } catch {
      if (this.generation !== generation) return;
      this.fail(persistenceFailure());
      return;
    }
    await this.finishPersistedOutcome(outcome, displayedText, generation);
  }

  private async finishPersistedOutcome(
    outcome: DictationOutcome,
    text: string,
    generation: number,
  ) {
    if (outcome.status === "failed") {
      this.fail({
        action: "reconnect",
        code: "provider_error",
        message: outcome.error?.message ?? "Dictation failed.",
        retryable: true,
      });
      return;
    }
    try {
      await this.dependencies.deliver(outcome, text);
      this.pendingDelivery = null;
      if (this.generation !== generation) return;
    } catch {
      if (this.generation !== generation) return;
      this.pendingDelivery = { outcome, text };
      this.fail(deliveryFailure());
      return;
    }
    this.update({
      error: null,
      finalText: "",
      resultHadText: Boolean(text.trim()),
      stage: "result",
      visibleText: "",
    });
  }

  private async completeBatch() {
    const plan = this.plan;
    if (!plan || isRealtimePlan(plan) || this.terminal) return;
    try {
      const result = await this.dependencies.transcribeBatch(
        plan,
        this.audioChunks,
      );
      await this.complete({
        result,
        sequence: 0,
        sessionId: `batch_${plan.requestId}`,
        type: "session.completed",
      });
    } catch (error) {
      this.fail({
        action: "reconnect",
        code: "provider_error",
        message:
          error instanceof Error
            ? error.message
            : "Batch transcription failed.",
        retryable: true,
      });
    }
  }

  private handleTransportError(message: string) {
    if (this.terminal || this.snapshot.stage === "error") return;
    this.clearConnectionTimer();
    this.clearFinalizationTimer();
    this.transport?.close();
    this.transport = null;
    this.fail({
      action: "reconnect",
      code: "interrupted_input",
      message,
      retryable: true,
    });
  }

  private async handleClose() {
    if (this.terminal || this.snapshot.stage === "error") return;
    this.clearConnectionTimer();
    this.clearFinalizationTimer();
    this.transport = null;
    await this.recoverTerminal();
  }

  private async recoverTerminal() {
    if (
      this.terminal ||
      this.snapshot.stage === "error" ||
      this.recoveryInFlight
    ) {
      return;
    }
    this.recoveryInFlight = true;
    if (
      this.snapshot.stage === "finalizing" &&
      this.snapshot.sessionId &&
      this.plan
    ) {
      try {
        const recovered = await this.dependencies.recover(
          this.plan,
          this.snapshot.sessionId,
          this.plan.credential,
        );
        if (
          recovered.type === "session.completed" ||
          recovered.type === "session.failed"
        ) {
          this.lastSequence = -1;
          await this.complete(recovered);
          return;
        }
      } catch {
        // The concrete recovery action remains available below.
      }
    }
    this.recoveryInFlight = false;
    this.fail({
      action: "reconnect",
      code: "interrupted_input",
      message: "The recording connection ended before a final result arrived.",
      retryable: true,
    });
  }

  private isCapturing() {
    return (
      this.snapshot.stage === "connecting" ||
      this.snapshot.stage === "listening" ||
      this.snapshot.stage === "finalizing"
    );
  }

  private fail(error: DictationFailure) {
    this.clearConnectionTimer();
    this.clearFinalizationTimer();
    this.update({ error, stage: "error" });
  }

  private update(patch: Partial<DictationWorkflowSnapshot>) {
    this.snapshot = { ...this.snapshot, ...patch };
    this.emit();
  }

  private emit() {
    this.dependencies.onChange({ ...this.snapshot });
  }

  private clearConnectionTimer() {
    if (!this.connectionTimer) return;
    clearTimeout(this.connectionTimer);
    this.connectionTimer = null;
  }

  private clearFinalizationTimer() {
    if (!this.finalizationTimer) return;
    clearTimeout(this.finalizationTimer);
    this.finalizationTimer = null;
  }
}

function rawArtifact(
  resultId: string,
  artifact: TranscriptionArtifact,
  modelId: string,
): PersistedArtifact {
  const content = isRecord(artifact.content) ? artifact.content : null;
  return {
    id: `${resultId}_raw`,
    kind: "raw",
    modelId,
    payload: artifact,
    text: artifact.text,
    timing: content,
  };
}

function artifactLanguage(artifact: TranscriptionArtifact) {
  if (!isRecord(artifact.language)) return null;
  if (typeof artifact.language.detected === "string") {
    return artifact.language.detected;
  }
  return typeof artifact.language.requested === "string"
    ? artifact.language.requested
    : null;
}

function isNoSpeechEvent(
  event: Extract<
    RealtimeProtocolEvent,
    { type: "session.completed" | "session.failed" }
  >,
) {
  if (event.result.text.trim() || event.type !== "session.failed") return false;
  const message = event.error.message.toLocaleLowerCase();
  return (
    message.includes("no transcript") ||
    message.includes("no speech") ||
    message.includes("empty transcript")
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function createIdentifier(prefix: "artifact" | "dictation") {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

function persistenceFailure(): DictationFailure {
  return {
    action: "retry-save",
    code: "persistence_failure",
    message: "The transcript is ready, but TimberVox could not save it.",
    retryable: true,
  };
}

function deliveryFailure(): DictationFailure {
  return {
    action: "retry-delivery",
    code: "delivery_failure",
    message: "The transcript is saved, but TimberVox could not deliver it.",
    retryable: true,
  };
}

function displayedText(outcome: DictationOutcome) {
  return (
    outcome.artifacts.find((artifact) => artifact.kind === "processed")?.text ??
    outcome.artifacts.find((artifact) => artifact.kind === "raw")?.text ??
    ""
  );
}

function isRealtimePlan(plan: DictationPlan | null) {
  return (
    plan?.executor.kind === "cloud-realtime" ||
    plan?.executor.kind === "local-realtime"
  );
}

export { DictationWorkflow };
export type { RealtimeTransportCallbacks, WorkflowDependencies };
