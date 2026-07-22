const fs = jest.requireActual("fs") as {
  readFileSync(filePath: string, encoding: string): string;
};
const path = jest.requireActual("path") as {
  join(...parts: string[]): string;
  resolve(...parts: string[]): string;
};

describe("iPhone audio session contract", () => {
  const projectRoot = path.resolve(".");
  const audioSession = fs.readFileSync(
    path.join(projectRoot, "src/features/audio/audio-session.ts"),
    "utf8",
  );
  const dictationSession = fs.readFileSync(
    path.join(projectRoot, "src/features/dictation/dictation-session.tsx"),
    "utf8",
  );
  const playback = fs.readFileSync(
    path.join(projectRoot, "src/features/history/history-playback-control.tsx"),
    "utf8",
  );

  it("uses separate recording and speaker-playback audio modes", () => {
    expect(audioSession).toContain("configureRecordingAudioSession");
    expect(audioSession).toContain("configurePlaybackAudioSession");
    expect(audioSession).toContain("allowsRecording: true");
    expect(audioSession).toContain("allowsRecording: false");
    expect(audioSession).toContain("shouldRouteThroughEarpiece: false");
  });

  it("releases the microphone session before history playback", () => {
    expect(dictationSession).toContain("await configurePlaybackAudioSession()");
    expect(playback).toContain("await session.endSession()");
    expect(playback).toContain("await configurePlaybackAudioSession()");
    expect(playback).toContain('testID="history-playback-error"');
  });
});
