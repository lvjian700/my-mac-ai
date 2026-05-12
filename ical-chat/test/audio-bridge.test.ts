import { describe, expect, test } from "bun:test";
import {
  convertF32Base64ToPcm16Base64,
  convertPcm16Base64ToF32Base64,
  decodeFrames,
  encodeFrame,
  resolveAudioHelperPath,
} from "../src/voice/audio-bridge.js";

describe("audio bridge framing", () => {
  test("encodes and decodes length-prefixed JSON frames", () => {
    const frame = { type: "activity", activity: "ready" };
    const state = { buffer: Buffer.alloc(0) };

    expect(decodeFrames(encodeFrame(frame), state)).toEqual([frame]);
  });

  test("decodes frames split across chunks", () => {
    const encoded = encodeFrame({ type: "shutdown" });
    const state = { buffer: Buffer.alloc(0) };

    expect(decodeFrames(encoded.subarray(0, 2), state)).toEqual([]);
    expect(decodeFrames(encoded.subarray(2), state)).toEqual([
      { type: "shutdown" },
    ]);
  });
});

describe("resolveAudioHelperPath", () => {
  test("prefers explicit helper override", () => {
    expect(
      resolveAudioHelperPath({
        env: { CALI_VOICE_AUDIO_HELPER: "/tmp/helper" },
        exists: () => false,
      }),
    ).toBe("/tmp/helper");
  });

  test("finds the helper installed beside the launched cali script", () => {
    const installed = "/Users/jlyu/.local/libexec/cali/cali-voice-audio";

    expect(
      resolveAudioHelperPath({
        env: {},
        argv: ["bun", "/Users/jlyu/.local/bin/cali"],
        execPath: "/Users/jlyu/.bun/bin/bun",
        moduleUrl: import.meta.url,
        exists: (path) => path === installed,
      }),
    ).toBe(installed);
  });
});

describe("PCM conversion", () => {
  test("converts float32 audio to pcm16 base64", () => {
    const f32 = Buffer.alloc(12);
    f32.writeFloatLE(-1, 0);
    f32.writeFloatLE(0, 4);
    f32.writeFloatLE(1, 8);

    const pcm16 = Buffer.from(
      convertF32Base64ToPcm16Base64(f32.toString("base64")),
      "base64",
    );

    expect(pcm16.readInt16LE(0)).toBe(-32768);
    expect(pcm16.readInt16LE(2)).toBe(0);
    expect(pcm16.readInt16LE(4)).toBe(32767);
  });

  test("converts pcm16 audio to float32 base64", () => {
    const pcm16 = Buffer.alloc(6);
    pcm16.writeInt16LE(-32768, 0);
    pcm16.writeInt16LE(0, 2);
    pcm16.writeInt16LE(32767, 4);

    const f32 = Buffer.from(
      convertPcm16Base64ToF32Base64(pcm16.toString("base64")),
      "base64",
    );

    expect(f32.readFloatLE(0)).toBe(-1);
    expect(f32.readFloatLE(4)).toBe(0);
    expect(f32.readFloatLE(8)).toBe(1);
  });
});
