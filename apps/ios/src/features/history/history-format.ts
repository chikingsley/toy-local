type HistoryMetadata = {
  createdAt: string;
  durationMs: number;
  status: "failed" | "no_speech" | "succeeded";
  text: string;
  wordCount: number;
};

function dictationDisplayText(item: Pick<HistoryMetadata, "status" | "text">) {
  if (item.text.trim()) return item.text.trim();
  if (item.status === "failed") return "Dictation failed";
  if (item.status === "no_speech") return "No speech detected";
  return "Empty dictation";
}

function formatDictationMetadata(item: HistoryMetadata) {
  return `${formatDate(item.createdAt)} · ${item.wordCount} ${item.wordCount === 1 ? "word" : "words"} · ${formatDuration(item.durationMs)}`;
}

function formatDate(value: string) {
  return new Date(value).toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

function formatDuration(durationMs: number) {
  const seconds = Math.max(0, Math.round(durationMs / 1_000));
  if (seconds < 60) return `${seconds}s`;
  const remainder = seconds % 60;
  return `${Math.floor(seconds / 60)}m${remainder ? ` ${remainder}s` : ""}`;
}

function formatBytes(bytes: number | null) {
  if (bytes === null) return "Unknown";
  if (bytes < 1_024) return `${bytes} B`;
  if (bytes < 1_048_576) return `${(bytes / 1_024).toFixed(1)} KB`;
  return `${(bytes / 1_048_576).toFixed(1)} MB`;
}

export {
  dictationDisplayText,
  formatBytes,
  formatDate,
  formatDictationMetadata,
  formatDuration,
};
