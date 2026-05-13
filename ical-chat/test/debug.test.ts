import { describe, expect, test } from "bun:test";
import {
  createDebugLogger,
  setDebugLoggingEnabled,
} from "../src/debug.js";

describe("createDebugLogger", () => {
  test("is disabled by default", () => {
    setDebugLoggingEnabled(false);
    const logger = createDebugLogger({});

    expect(logger.enabled).toBe(false);
  });

  test("can be enabled for Realtime diagnostics", () => {
    setDebugLoggingEnabled(false);
    const logger = createDebugLogger({ CALI_DEBUG_REALTIME: "1" });

    expect(logger.enabled).toBe(true);
  });

  test("can be enabled at runtime by CLI flag", () => {
    const logger = createDebugLogger({});

    setDebugLoggingEnabled(true);
    expect(logger.enabled).toBe(true);

    setDebugLoggingEnabled(false);
  });
});
