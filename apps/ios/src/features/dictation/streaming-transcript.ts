export type StreamingTranscript = {
  committed: string;
  uncommitted: string;
};

const EMPTY_STREAMING_TRANSCRIPT: StreamingTranscript = {
  committed: "",
  uncommitted: "",
};

type StreamingTranscriptEvent =
  | { text: string; type: "committed" }
  | { text: string; type: "delta" }
  | { text: string; type: "final" }
  | { text: string; type: "interim" };

function reduceStreamingTranscript(
  state: StreamingTranscript,
  event: StreamingTranscriptEvent,
): StreamingTranscript {
  switch (event.type) {
    case "delta":
      return { ...state, uncommitted: state.uncommitted + event.text };
    case "interim":
      return { ...state, uncommitted: event.text };
    case "committed":
      return {
        committed: state.committed + event.text,
        uncommitted: "",
      };
    case "final":
      return { committed: event.text, uncommitted: "" };
  }
}

function visibleStreamingTranscript(state: StreamingTranscript) {
  return state.committed + state.uncommitted;
}

export {
  EMPTY_STREAMING_TRANSCRIPT,
  reduceStreamingTranscript,
  visibleStreamingTranscript,
};
export type { StreamingTranscriptEvent };
