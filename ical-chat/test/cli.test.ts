import { describe, expect, test } from "bun:test";
import { parseCliOptions } from "../src/cli.js";

describe("parseCliOptions", () => {
  test("defaults to text mode", () => {
    expect(parseCliOptions([])).toEqual({ mode: "text", debug: false });
  });

  test("--voice selects voice mode", () => {
    expect(parseCliOptions(["--voice"])).toEqual({
      mode: "voice",
      debug: false,
    });
  });

  test("--debug enables diagnostics", () => {
    expect(parseCliOptions(["--voice", "--debug"])).toEqual({
      mode: "voice",
      debug: true,
    });
  });

  test("unknown flags throw a useful error", () => {
    expect(() => parseCliOptions(["--bogus"])).toThrow(
      "Unknown flag: --bogus",
    );
  });
});
