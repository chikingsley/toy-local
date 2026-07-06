import { describe, expect, it } from "vitest";

import { app } from "../../src";

describe("route contracts", () => {
  it("exposes health", async () => {
    const response = await app.request("/health");
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      ok: true,
      service: "timbervox",
    });
  });

  it("exposes OpenAPI JSON", async () => {
    const response = await app.request("/openapi.json");
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.info.title).toBe("TimberVox Cloudflare API");
    expect(body.openapi).toBe("3.1.0");
    expect(Object.keys(body.paths)).toContain("/v1/realtime");
  });

  it("requires websocket upgrade for realtime sessions", async () => {
    const response = await app.request("/v1/realtime");
    expect(response.status).toBe(426);
    await expect(response.text()).resolves.toBe("expected websocket upgrade");
  });

  it("requires an explicit realtime model", async () => {
    const response = await app.request("/v1/realtime", {
      headers: { upgrade: "websocket" },
    });
    expect(response.status).toBe(400);
    const body = await response.json();
    expect(body.error).toBe("invalid request");
  });

  it("rejects unsupported realtime models before session allocation", async () => {
    const response = await app.request("/v1/realtime?model=not-real", {
      headers: { upgrade: "websocket" },
    });
    expect(response.status).toBe(400);
    const body = await response.json();
    expect(body.error).toBe("unsupported realtime model: not-real");
  });

  it("rejects invalid upload reservations before storage", async () => {
    const response = await app.request("/v1/uploads", {
      body: JSON.stringify({ filename: "", extra: true }),
      headers: { "content-type": "application/json" },
      method: "POST",
    });
    expect(response.status).toBe(400);
    const body = await response.json();
    expect(body.error).toBe("invalid request");
    expect(body.issues.length).toBeGreaterThan(0);
  });

  it("rejects invalid transcription jobs before enqueue", async () => {
    const response = await app.request("/v1/transcriptions", {
      body: JSON.stringify({ asr_model: "", input_key: "uploads/u/source" }),
      headers: { "content-type": "application/json" },
      method: "POST",
    });
    expect(response.status).toBe(400);
    const body = await response.json();
    expect(body.error).toBe("invalid request");
    expect(body.issues.length).toBeGreaterThan(0);
  });
});
