import {
  defaultTranscriptionModel,
  languageDisplayName,
  languageModelFamilyKey,
  languageModelDetail,
  languageModelDisplayName,
  languageModelsForPicker,
  modelDisplayName,
  parseModelCatalog,
  selectedRoute,
  transcriptionModelDetail,
} from "@/features/modes/model-catalog";
import {
  applyPreset,
  buildPresetProcessingRequest,
  createModeDraft,
  displayedArtifactForPreset,
  PRESET_DEFINITIONS,
} from "@/features/modes/preset-contracts";
import { normalizeModeDraft } from "@/features/modes/mode-validation";
import { MODE_PRESET_FIXTURES } from "./fixtures/mode-preset-fixtures";

const catalog = parseModelCatalog({
  models: [
    { id: "cheap-transform", kind: "language", provider: "example" },
    {
      accuracy: {
        benchmark: "Deepgram mixed-domain audio",
        metric: "wer",
        source: "provider-published",
        value: 10.7,
      },
      id: "deepgram-nova-2",
      kind: "transcription",
      provider: "deepgram",
      routes: {
        batch: {
          model: "nova",
          provider: "deepgram",
          supported_languages: ["en", "es"],
          supports_automatic_language: true,
          supports_diarization: true,
        },
      },
    },
    {
      accuracy: {
        benchmark: "English FLEURS at 240 ms",
        metric: "wer",
        source: "provider-published",
        value: 5.9,
      },
      id: "mistral-voxtral-mini-latest",
      kind: "transcription",
      provider: "mistral",
      speed: {
        approximate: false,
        kind: "realtime",
        source: "route-capability",
      },
      routes: {
        realtime: {
          model: "voxtral-realtime",
          provider: "mistral",
          supported_languages: ["en", "fr"],
          supports_automatic_language: true,
          supports_diarization: false,
        },
      },
    },
    {
      accuracy: {
        benchmark: "Deepgram mixed-domain audio",
        metric: "wer",
        source: "provider-published",
        value: 6.84,
      },
      id: "deepgram-nova-3",
      kind: "transcription",
      provider: "deepgram",
      speed: {
        approximate: false,
        kind: "realtime",
        source: "route-capability",
      },
      routes: {
        realtime: {
          model: "nova-3",
          provider: "deepgram",
          supported_languages: ["en", "es"],
          supports_automatic_language: true,
          supports_diarization: true,
        },
      },
    },
  ],
  presentation_schema_version: 1,
});

describe("mode contracts", () => {
  it("requires the current model presentation schema", () => {
    expect(() => parseModelCatalog({ models: [] })).toThrow(
      "The model presentation schema is unsupported.",
    );
    expect(() =>
      parseModelCatalog({ models: [], presentation_schema_version: 2 }),
    ).toThrow("The model presentation schema is unsupported.");
  });

  it("defines concrete output contracts for every available preset", () => {
    expect(PRESET_DEFINITIONS.voice.defaultName).toBe("Voice to Text");
    expect(Object.values(PRESET_DEFINITIONS)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ usesProcessing: false }),
        expect.objectContaining({ usesProcessing: true }),
      ]),
    );
    for (const definition of Object.values(PRESET_DEFINITIONS)) {
      expect(definition.defaultDescription.length).toBeGreaterThan(12);
      expect(definition.outputContract.length).toBeGreaterThan(20);
    }
  });

  it.each(MODE_PRESET_FIXTURES)(
    "$presetKind defines the Worker request and displayed artifact",
    (fixture) => {
      expect(
        buildPresetProcessingRequest({
          presetKind: fixture.presetKind,
          processingInstructions: fixture.processingInstructions,
          processingModelId: fixture.processingModelId,
          transcript: fixture.inputTranscript,
        }),
      ).toEqual(fixture.expectedRequest);
      expect(
        displayedArtifactForPreset({
          presetKind: fixture.presetKind,
          transcript: fixture.inputTranscript,
          transformedText: fixture.transformedText,
        }),
      ).toBe(fixture.displayedArtifact);
    },
  );

  it("tracks a preset's suggested icon until the user chooses one", () => {
    const voice = createModeDraft("voice");
    const message = applyPreset(voice, "message");
    expect(message.iconKey).toBe("message.fill");

    const customized = {
      ...message,
      iconCustomized: true,
      iconKey: "star.fill",
    };
    expect(applyPreset(customized, "note").iconKey).toBe("star.fill");
  });

  it("derives default route and capabilities from the Worker response", () => {
    const preferred = defaultTranscriptionModel(catalog);
    expect(preferred.id).toBe("mistral-voxtral-mini-latest");
    expect(selectedRoute(preferred)?.model).toBe("voxtral-realtime");

    const normalized = normalizeModeDraft(
      {
        ...createModeDraft("voice", preferred.id),
        identifySpeakers: true,
        language: "es",
      },
      catalog,
    );
    expect(normalized.language).toBeNull();
    expect(normalized.identifySpeakers).toBe(false);
  });

  it("presents Worker language codes with the same labels as the Mac app", () => {
    expect(languageDisplayName("en")).toBe("English");
    expect(languageDisplayName("fr")).toBe("French");
    expect(languageDisplayName("multi")).toBe("Multilingual");
    expect(languageDisplayName("yue")).toBe("Cantonese");
  });

  it("presents output throughput and curved intelligence when published", () => {
    const unpublished = catalog.languageModels[0];
    const publishedCatalog = parseModelCatalog({
      models: [
        {
          id: "cerebras-gemma-4-31b",
          intelligence: {
            display_score: 5.2,
            index: 21.8,
            measured_at: "2026-07-14",
            profile: "gemma-4-31b-non-reasoning",
            source: "artificial-analysis",
            source_version: "4.1",
          },
          kind: "language",
          provider: "cerebras",
          speed: {
            approximate: true,
            kind: "effective-tps",
            measured_at: "2026-07-14",
            profile: "timbervox-text-stream-v2",
            source: "timbervox-benchmark",
            value: 320.9,
          },
        },
        {
          id: "groq-openai/gpt-oss-20b",
          intelligence: {
            display_score: 3.4,
            index: 14.3,
            measured_at: "2026-07-14",
            profile: "gpt-oss-20b-low",
            source: "artificial-analysis",
            source_version: "4.1",
          },
          kind: "language",
          provider: "groq",
        },
        {
          id: "anthropic-claude-sonnet-5",
          intelligence: {
            display_score: 10,
            index: 41.7,
            measured_at: "2026-07-14",
            profile: "claude-sonnet-5-non-reasoning",
            source: "artificial-analysis",
            source_version: "4.1",
          },
          kind: "language",
          provider: "anthropic",
        },
        {
          id: "deepgram-nova-3",
          kind: "transcription",
          provider: "deepgram",
          routes: {
            realtime: {
              model: "nova-3",
              provider: "deepgram",
              supported_languages: ["en"],
              supports_automatic_language: true,
              supports_diarization: true,
            },
          },
        },
      ],
      presentation_schema_version: 1,
    });

    expect(languageModelDetail(unpublished, catalog.languageModels)).toBe(
      "Intelligence not rated",
    );
    expect(
      languageModelDetail(
        publishedCatalog.languageModels[0],
        publishedCatalog.languageModels,
      ),
    ).toBe("~320.9 effective tok/s · 5.2/10 intelligence");
    expect(
      languageModelDetail(
        publishedCatalog.languageModels[1],
        publishedCatalog.languageModels,
      ),
    ).toBe("3.4/10 intelligence");
    expect(
      languageModelDetail(
        publishedCatalog.languageModels[2],
        publishedCatalog.languageModels,
      ),
    ).toBe("10.0/10 intelligence");
    expect(
      languageModelDisplayName({
        id: "cerebras-zai-glm-4.7",
        provider: "cerebras",
      }),
    ).toBe("Z.ai GLM 4.7");
  });

  it("presents only the authoritative Mistral latest routes", () => {
    const mistralCatalog = parseModelCatalog({
      models: [
        ...[
          "mistral-mistral-large-latest",
          "mistral-mistral-medium-latest",
          "mistral-mistral-small-latest",
        ].map((id) => ({ id, kind: "language", provider: "mistral" })),
        {
          id: "deepgram-nova-3",
          kind: "transcription",
          provider: "deepgram",
          routes: {
            realtime: {
              model: "nova-3",
              provider: "deepgram",
              supported_languages: ["en"],
              supports_automatic_language: true,
              supports_diarization: true,
            },
          },
        },
      ],
      presentation_schema_version: 1,
    });
    const visible = languageModelsForPicker(mistralCatalog.languageModels);

    expect(visible.map((model) => model.id)).toEqual([
      "mistral-mistral-large-latest",
      "mistral-mistral-medium-latest",
      "mistral-mistral-small-latest",
    ]);
    expect(visible.map(languageModelDisplayName)).toEqual([
      "Mistral Large",
      "Mistral Medium",
      "Mistral Small",
    ]);
    expect(
      languageModelFamilyKey({
        id: "mistral-mistral-small-latest",
        provider: "mistral",
      }),
    ).toBe(languageModelFamilyKey(visible[2]));
  });

  it("automatically presents the delivery behavior without a realtime setting", () => {
    const realtime = catalog.transcriptionModels.find(
      (model) => model.id === "mistral-voxtral-mini-latest",
    );
    const batch = catalog.transcriptionModels.find(
      (model) => model.id === "deepgram-nova-2",
    );
    const nova3 = catalog.transcriptionModels.find(
      (model) => model.id === "deepgram-nova-3",
    );

    expect(realtime && transcriptionModelDetail(realtime)).toBe(
      "Realtime · 5.9% WER",
    );
    expect(batch && transcriptionModelDetail(batch)).toBe(
      "After recording · 10.7% WER",
    );
    expect(nova3 && transcriptionModelDetail(nova3)).toBe(
      "Realtime · 6.84% WER",
    );
  });

  it("presents the paired local batch and realtime package as one model", () => {
    const local = catalog.transcriptionModels.find(
      (model) => model.id === "local-parakeet-110m",
    );

    expect(local && transcriptionModelDetail(local)).toBe(
      "Local · ~452 MB · 3.0% WER",
    );
    expect(local && modelDisplayName(local)).toBe("Parakeet Local");
    expect(selectedRoute(local, true)?.model).toBe(
      "parakeet-realtime-eou-120m-coreml/320ms",
    );
    expect(selectedRoute(local, false)?.model).toBe(
      "parakeet-tdt-ctc-110m-coreml",
    );
  });
});
