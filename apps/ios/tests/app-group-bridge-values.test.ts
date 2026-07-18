import {
  normalizeBridgeBoolean,
  normalizeBridgeNumber,
} from "@/features/keyboard/app-group-bridge";

describe("App Group bridge value normalization", () => {
  it.each([true, 1, "1", "true", "TRUE", "yes"])(
    "reads Swift truth value %p",
    (value) => {
      expect(normalizeBridgeBoolean(value)).toBe(true);
    },
  );

  it.each([false, 0, "0", "false", "no", null, undefined])(
    "reads false value %p",
    (value) => {
      expect(normalizeBridgeBoolean(value)).toBe(false);
    },
  );

  it("normalizes Swift booleans at numeric bridge boundaries", () => {
    expect(normalizeBridgeNumber("true")).toBe(1);
    expect(normalizeBridgeNumber("false")).toBe(0);
    expect(normalizeBridgeNumber("not-a-number")).toBe(0);
  });
});
