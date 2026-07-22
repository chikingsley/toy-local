import { transcribeCloudBatch } from "@/features/dictation/cloud-batch-client";
import type { DictationPlan } from "@/features/dictation/dictation-types";

const plan: DictationPlan = {
  credential: "mobile-session",
  entryPoint: "app",
  executor: {
    kind: "cloud-batch",
    model: "voxtral-mini-latest",
    provider: "mistral",
  },
  mode: {
    asrModelId: "mistral-voxtral-mini-latest",
    description: "Voice",
    iconKey: "person.wave.2.fill",
    id: "voice",
    identifySpeakers: false,
    language: "en",
    name: "Voice to Text",
    presetKind: "voice",
    processingInstructions: null,
    processingModelId: null,
    realtimeModel: "voxtral-mini-transcribe-realtime-2602",
  },
  requestId: "request_1",
};

describe("cloud batch transcription", () => {
  it("uploads one WAV and submits the selected batch route", async () => {
    const fetchImplementation = jest
      .fn()
      .mockResolvedValueOnce(
        jsonResponse({
          input_key: "inputs/request_1.wav",
          transfer: {
            headers: { "x-upload": "signed" },
            kind: "single",
            url: "https://uploads.example/request_1",
          },
          upload_id: "upload_1",
        }),
      )
      .mockResolvedValueOnce(emptyResponse())
      .mockResolvedValueOnce(jsonResponse({ status: "completed" }))
      .mockResolvedValueOnce(
        jsonResponse({
          result: { schema_version: 2, text: "Cloud batch result." },
          status: "succeeded",
        }),
      ) as jest.MockedFunction<typeof fetch>;

    await expect(
      transcribeCloudBatch(
        plan,
        [new Uint8Array([1, 2, 3, 4]).buffer],
        fetchImplementation,
      ),
    ).resolves.toMatchObject({
      schema_version: 2,
      text: "Cloud batch result.",
    });

    expect(fetchImplementation).toHaveBeenCalledTimes(4);
    const uploadRequest = fetchImplementation.mock.calls[1];
    expect(uploadRequest[0]).toBe("https://uploads.example/request_1");
    expect(uploadRequest[1]?.method).toBe("PUT");
    expect((uploadRequest[1]?.body as Uint8Array).byteLength).toBe(48);

    const transcriptionRequest = fetchImplementation.mock.calls[3][0];
    expect(transcriptionRequest).toBeInstanceOf(Request);
    expect((transcriptionRequest as Request).url).toContain(
      "/v1/transcriptions",
    );
    expect(
      JSON.parse(await (transcriptionRequest as Request).text()),
    ).toMatchObject({
      asr_model: "voxtral-mini-latest",
      input_key: "inputs/request_1.wav",
      language: "en",
      sync: true,
    });
  });
});

function jsonResponse(value: Record<string, unknown>) {
  return {
    headers: { get: () => "application/json" },
    json: async () => value,
    ok: true,
    status: 200,
    text: async () => JSON.stringify(value),
  } as unknown as Response;
}

function emptyResponse() {
  return {
    headers: { get: () => "application/json" },
    ok: true,
    status: 200,
    text: async () => "",
  } as unknown as Response;
}
