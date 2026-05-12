export const DEFAULT_VOICE_IDLE_TIMEOUT_MS = 60_000;

export interface IdleTimeoutScheduler {
  setTimeout(callback: () => void, delayMs: number): unknown;
  clearTimeout(handle: unknown): void;
}

export interface VoiceIdleTimeout {
  reset(): void;
  stop(): void;
}

export interface VoiceIdleTimeoutOptions {
  shutdown(): void;
  timeoutMs?: number;
  scheduler?: IdleTimeoutScheduler;
}

const defaultScheduler: IdleTimeoutScheduler = {
  setTimeout: (callback, delayMs) => globalThis.setTimeout(callback, delayMs),
  clearTimeout: (handle) => globalThis.clearTimeout(handle as never),
};

export function startVoiceIdleTimeout({
  shutdown,
  timeoutMs = DEFAULT_VOICE_IDLE_TIMEOUT_MS,
  scheduler = defaultScheduler,
}: VoiceIdleTimeoutOptions): VoiceIdleTimeout {
  let stopped = false;
  let handle: unknown;

  const clear = () => {
    if (handle !== undefined) {
      scheduler.clearTimeout(handle);
      handle = undefined;
    }
  };

  const schedule = () => {
    clear();
    handle = scheduler.setTimeout(() => {
      if (stopped) {
        return;
      }

      stopped = true;
      handle = undefined;
      shutdown();
    }, timeoutMs);
  };

  schedule();

  return {
    reset() {
      if (!stopped) {
        schedule();
      }
    },
    stop() {
      stopped = true;
      clear();
    },
  };
}
