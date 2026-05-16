import { describe, expect, test } from "bun:test";
import { parseCliOptions } from "../src/cli.js";

describe("parseCliOptions", () => {
  test("defaults to text mode", () => {
    expect(parseCliOptions([])).toEqual({ mode: "text", debug: false });
  });

  test("--debug enables diagnostics", () => {
    expect(parseCliOptions(["--debug"])).toEqual({
      mode: "text",
      debug: true,
    });
  });

  test("unknown flags throw a useful error", () => {
    expect(() => parseCliOptions(["--bogus"])).toThrow(
      "Unknown flag: --bogus",
    );
  });
});
