import {
  parseRealtimeEvent,
  RealtimeProtocolError,
} from "@/features/dictation/realtime-protocol";

describe("mobile realtime protocol", () => {
  it("parses the current completed-event artifact instead of a legacy transcript field", () => {
    expect(
      parseRealtimeEvent(
        JSON.stringify({
          protocol_version: 1,
          result: { schema_version: 2, text: "Canonical result" },
          sequence: 4,
          session_id: "rt_123",
          status: "succeeded",
          transcript: "wrong legacy field",
          type: "session.completed",
        }),
      ),
    ).toEqual({
      result: { schema_version: 2, text: "Canonical result" },
      sequence: 4,
      sessionId: "rt_123",
      type: "session.completed",
    });
  });

  it("rejects unsupported protocol and artifact versions", () => {
    expect(() =>
      parseRealtimeEvent(
        JSON.stringify({
          protocol_version: 2,
          sequence: 1,
          session_id: "rt_123",
          text: "hello",
          type: "transcript.delta",
        }),
      ),
    ).toThrow(RealtimeProtocolError);
    expect(() =>
      parseRealtimeEvent(
        JSON.stringify({
          protocol_version: 1,
          result: { schema_version: 1, text: "old" },
          sequence: 2,
          session_id: "rt_123",
          type: "session.completed",
        }),
      ),
    ).toThrow("unsupported artifact schema");
  });

  it("ignores non-contract transport acknowledgements", () => {
    expect(
      parseRealtimeEvent(JSON.stringify({ type: "audio.received" })),
    ).toBeNull();
  });
});
