import { describe, expect, test } from "bun:test";
import { parseCliOptions } from "../src/cli.js";

describe("parseCliOptions", () => {
  test("defaults to text mode", () => {
    expect(parseCliOptions([])).toEqual({ mode: "text" });
  });

  test("--voice selects voice mode", () => {
    expect(parseCliOptions(["--voice"])).toEqual({ mode: "voice" });
  });

  test("unknown flags throw a useful error", () => {
    expect(() => parseCliOptions(["--bogus"])).toThrow(
      "Unknown flag: --bogus",
    );
  });
});
