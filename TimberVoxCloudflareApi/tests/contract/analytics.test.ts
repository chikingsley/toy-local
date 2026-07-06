import { describe, expect, it } from "vitest";

import { usageAnalyticsQuery } from "../../src/analytics/engine";
import type { Env } from "../../src/bindings";

describe("Analytics Engine query builder", () => {
  it("builds a bounded usage summary query with escaped account keys", () => {
    const { dataset, query } = usageAnalyticsQuery(
      { TIMBERVOX_USAGE_DATASET: "timbervox_usage" } as Env,
      {
        accountKey: "acct_'one",
        limit: 10,
        sinceMinutes: 60,
      }
    );

    expect(dataset).toBe("timbervox_usage");
    expect(query).toContain("FROM timbervox_usage");
    expect(query).toContain("timestamp > NOW() - INTERVAL '60' MINUTE");
    expect(query).toContain("index1 = 'acct_''one'");
    expect(query).toContain("LIMIT 10");
  });

  it("rejects unsafe dataset identifiers", () => {
    expect(() =>
      usageAnalyticsQuery({ TIMBERVOX_USAGE_DATASET: "bad-name;" } as Env)
    ).toThrow("invalid analytics dataset name");
  });
});
