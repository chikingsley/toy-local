import { Directory, File, Paths } from "expo-file-system";

const RECORDING_FORMAT = "audio/wav;codec=pcm_s16le;rate=16000;channels=1";
const recordingsDirectory = new Directory(Paths.document, "recordings");

type RecordingFile = {
  format: typeof RECORDING_FORMAT;
  sizeBytes: number;
  uri: string;
};

function persistRecording(
  chunks: ArrayBuffer[],
  requestId: string,
  resultId: string,
): RecordingFile | null {
  if (chunks.length === 0) return null;
  recordingsDirectory.create({ idempotent: true, intermediates: true });
  const file = new File(
    recordingsDirectory,
    `${safeFileComponent(requestId)}_${safeFileComponent(resultId)}.wav`,
  );
  const bytes = makeWaveFile(chunks);
  file.create({ overwrite: true, intermediates: true });
  file.write(bytes);
  return {
    format: RECORDING_FORMAT,
    sizeBytes: bytes.byteLength,
    uri: file.uri,
  };
}

async function importWaveRecording(
  sourceUri: string,
  requestId: string,
  resultId: string,
): Promise<RecordingFile | null> {
  const source = new File(sourceUri);
  if (!source.exists) return null;
  recordingsDirectory.create({ idempotent: true, intermediates: true });
  const destination = new File(
    recordingsDirectory,
    `${safeFileComponent(requestId)}_${safeFileComponent(resultId)}.wav`,
  );
  await source.copy(destination, { overwrite: true });
  const sizeBytes = destination.size ?? 0;
  source.delete();
  return {
    format: RECORDING_FORMAT,
    sizeBytes,
    uri: destination.uri,
  };
}

function deleteRecording(uri: string | null) {
  if (!uri) return;
  const file = new File(uri);
  if (file.exists) file.delete();
}

function makeWaveFile(chunks: ArrayBuffer[]) {
  const dataLength = chunks.reduce(
    (total, chunk) => total + chunk.byteLength,
    0,
  );
  const output = new Uint8Array(44 + dataLength);
  const view = new DataView(output.buffer);
  writeAscii(view, 0, "RIFF");
  view.setUint32(4, 36 + dataLength, true);
  writeAscii(view, 8, "WAVE");
  writeAscii(view, 12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, 16_000, true);
  view.setUint32(28, 32_000, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeAscii(view, 36, "data");
  view.setUint32(40, dataLength, true);
  let offset = 44;
  for (const chunk of chunks) {
    output.set(new Uint8Array(chunk), offset);
    offset += chunk.byteLength;
  }
  return output;
}

function safeFileComponent(value: string) {
  return value.replace(/[^a-zA-Z0-9_-]/g, "_");
}

function writeAscii(view: DataView, offset: number, value: string) {
  for (let index = 0; index < value.length; index += 1) {
    view.setUint8(offset + index, value.charCodeAt(index));
  }
}

export {
  deleteRecording,
  importWaveRecording,
  makeWaveFile,
  persistRecording,
  RECORDING_FORMAT,
};
export type { RecordingFile };
