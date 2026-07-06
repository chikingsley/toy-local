import type { Env } from "../bindings";
import { newId } from "../lib/ids";

const nowIso = (): string => new Date().toISOString();

export const createUpload = async (
  env: Env,
  input: { contentType?: string; filename?: string }
) => {
  const id = newId("upl");
  const inputKey = `uploads/${id}/source`;
  await env.DB.prepare(
    `INSERT INTO uploads (id, input_key, filename, content_type, created_at)
     VALUES (?, ?, ?, ?, ?)`
  )
    .bind(
      id,
      inputKey,
      input.filename ?? null,
      input.contentType ?? null,
      nowIso()
    )
    .run();
  return {
    input_key: inputKey,
    upload_id: id,
    upload_url: `/v1/uploads/${id}`,
  };
};

export const completeUpload = async (
  env: Env,
  uploadId: string,
  body: ReadableStream,
  contentType: string
) => {
  const row = await env.DB.prepare("SELECT input_key FROM uploads WHERE id = ?")
    .bind(uploadId)
    .first<{ input_key: string }>();
  if (!row) {
    return null;
  }
  const object = await env.ARTIFACTS.put(row.input_key, body, {
    httpMetadata: { contentType },
  });
  await env.DB.prepare(
    `UPDATE uploads
       SET size_bytes = ?, content_type = COALESCE(content_type, ?), completed_at = ?
     WHERE id = ?`
  )
    .bind(object.size, contentType, nowIso(), uploadId)
    .run();
  return { input_key: row.input_key, size_bytes: object.size };
};
