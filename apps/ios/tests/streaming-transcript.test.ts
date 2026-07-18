import {
  EMPTY_STREAMING_TRANSCRIPT,
  reduceStreamingTranscript,
  visibleStreamingTranscript,
} from "@/features/dictation/streaming-transcript";

describe("streaming transcript reducer", () => {
  it("appends deltas and replaces only the uncommitted interim portion", () => {
    let state = EMPTY_STREAMING_TRANSCRIPT;
    state = reduceStreamingTranscript(state, { text: "Hel", type: "delta" });
    expect(visibleStreamingTranscript(state)).toBe("Hel");

    state = reduceStreamingTranscript(state, {
      text: "Hello",
      type: "interim",
    });
    expect(visibleStreamingTranscript(state)).toBe("Hello");

    state = reduceStreamingTranscript(state, {
      text: "Hello ",
      type: "committed",
    });
    expect(visibleStreamingTranscript(state)).toBe("Hello ");

    state = reduceStreamingTranscript(state, { text: "wor", type: "delta" });
    expect(visibleStreamingTranscript(state)).toBe("Hello wor");

    state = reduceStreamingTranscript(state, {
      text: "world",
      type: "interim",
    });
    expect(visibleStreamingTranscript(state)).toBe("Hello world");
  });

  it("replaces every partial with the canonical final text", () => {
    const partial = reduceStreamingTranscript(EMPTY_STREAMING_TRANSCRIPT, {
      text: "A rough partial",
      type: "delta",
    });
    const final = reduceStreamingTranscript(partial, {
      text: "The canonical final.",
      type: "final",
    });
    expect(final).toEqual({
      committed: "The canonical final.",
      uncommitted: "",
    });
    expect(visibleStreamingTranscript(final)).toBe("The canonical final.");
  });
});
