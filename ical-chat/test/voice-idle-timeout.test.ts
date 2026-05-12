import { describe, expect, test } from "bun:test";
import {
  DEFAULT_VOICE_IDLE_TIMEOUT_MS,
  startVoiceIdleTimeout,
  type IdleTimeoutScheduler,
} from "../src/voice/idle-timeout.js";

class FakeScheduler implements IdleTimeoutScheduler {
  private nextHandle = 1;
  private readonly timers = new Map<number, () => void>();

  setTimeout(callback: () => void, delayMs: number): unknown {
    expect(delayMs).toBe(DEFAULT_VOICE_IDLE_TIMEOUT_MS);
    const handle = this.nextHandle++;
    this.timers.set(handle, callback);
    return handle;
  }

  clearTimeout(handle: unknown): void {
    this.timers.delete(handle as number);
  }

  get pendingTimerCount(): number {
    return this.timers.size;
  }

  fireNext(): void {
    const [handle, callback] = this.timers.entries().next().value ?? [];
    if (handle === undefined || callback === undefined) {
      throw new Error("No pending timer");
    }

    this.timers.delete(handle);
    callback();
  }
}

describe("startVoiceIdleTimeout", () => {
  test("starts the idle timer on launch", () => {
    const scheduler = new FakeScheduler();

    startVoiceIdleTimeout({
      scheduler,
      shutdown: () => {},
    });

    expect(scheduler.pendingTimerCount).toBe(1);
  });

  test("calls shutdown after the idle timeout", () => {
    const scheduler = new FakeScheduler();
    let shutdownCount = 0;

    startVoiceIdleTimeout({
      scheduler,
      shutdown: () => {
        shutdownCount += 1;
      },
    });

    scheduler.fireNext();

    expect(shutdownCount).toBe(1);
    expect(scheduler.pendingTimerCount).toBe(0);
  });

  test("resets the timer on activity", () => {
    const scheduler = new FakeScheduler();
    let shutdownCount = 0;

    const idleTimeout = startVoiceIdleTimeout({
      scheduler,
      shutdown: () => {
        shutdownCount += 1;
      },
    });

    idleTimeout.reset();

    expect(scheduler.pendingTimerCount).toBe(1);

    scheduler.fireNext();

    expect(shutdownCount).toBe(1);
  });

  test("stop prevents shutdown", () => {
    const scheduler = new FakeScheduler();
    let shutdownCount = 0;

    const idleTimeout = startVoiceIdleTimeout({
      scheduler,
      shutdown: () => {
        shutdownCount += 1;
      },
    });

    idleTimeout.stop();

    expect(scheduler.pendingTimerCount).toBe(0);
    expect(() => scheduler.fireNext()).toThrow("No pending timer");
    expect(shutdownCount).toBe(0);
  });
});
