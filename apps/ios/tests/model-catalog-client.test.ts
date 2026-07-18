import { fetchModelCatalog } from "@/features/modes/model-catalog";

describe("model catalog client", () => {
  it("authenticates the catalog request with the TimberVox credential", async () => {
    const fetchImplementation = jest.fn().mockResolvedValue({
      json: async () => ({
        models: [
          {
            id: "deepgram-nova-3",
            kind: "transcription",
            provider: "deepgram",
            routes: {
              batch: {
                model: "nova-3",
                provider: "deepgram",
                supported_languages: ["en"],
                supports_automatic_language: true,
                supports_diarization: true,
                upstream_model: "nova-3",
              },
            },
            upstream_model: "nova-3",
          },
        ],
        presentation_schema_version: 1,
      }),
      ok: true,
      status: 200,
    }) as jest.MockedFunction<typeof fetch>;

    await expect(
      fetchModelCatalog(undefined, "mobile-session", fetchImplementation),
    ).resolves.toMatchObject({
      transcriptionModels: expect.arrayContaining([
        expect.objectContaining({ id: "deepgram-nova-3" }),
      ]),
    });

    expect(fetchImplementation).toHaveBeenCalledWith(
      "https://timbervox.peacockery.studio/v1/models",
      expect.objectContaining({
        headers: { Authorization: "Bearer mobile-session" },
      }),
    );
  });

  it("fails before the request when no TimberVox credential is available", async () => {
    const fetchImplementation = jest.fn() as jest.MockedFunction<typeof fetch>;

    await expect(
      fetchModelCatalog(undefined, "", fetchImplementation),
    ).rejects.toThrow("active TimberVox session");
    expect(fetchImplementation).not.toHaveBeenCalled();
  });
});
