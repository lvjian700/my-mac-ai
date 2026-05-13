import { describe, expect, test } from "bun:test";
import { createDebugLogger } from "../src/debug.js";

describe("createDebugLogger", () => {
  test("is disabled by default", () => {
    const logger = createDebugLogger({});

    expect(logger.enabled).toBe(false);
  });

  test("can be enabled for Realtime diagnostics", () => {
    const logger = createDebugLogger({ CALI_DEBUG_REALTIME: "1" });

    expect(logger.enabled).toBe(true);
  });
});
