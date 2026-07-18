import { parseServerSentEvents } from "@/features/dictation/text-processing-client";

describe("text processing SSE", () => {
  it("reads the provider-neutral stream contract", () => {
    const events = parseServerSentEvents(
      [
        'id: 1\nevent: stream.started\ndata: {"protocol_version":1,"type":"stream.started"}',
        'id: 2\nevent: text.delta\ndata: {"protocol_version":1,"type":"text.delta","delta":"Hello "}',
        'id: 3\nevent: text.delta\ndata: {"protocol_version":1,"type":"text.delta","delta":"world"}',
        'id: 4\nevent: stream.completed\ndata: {"protocol_version":1,"type":"stream.completed"}',
      ].join("\n\n"),
    );
    expect(events.map((event) => event.type)).toEqual([
      "stream.started",
      "text.delta",
      "text.delta",
      "stream.completed",
    ]);
  });
});
