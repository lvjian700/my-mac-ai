export interface DebugLogger {
  enabled: boolean;
  log(scope: string, message: string, data?: Record<string, unknown>): void;
}

export function createDebugLogger(
  env: NodeJS.ProcessEnv = process.env,
): DebugLogger {
  const enabled =
    env.CALI_DEBUG_REALTIME === "1" ||
    env.CALI_DEBUG_REALTIME === "true" ||
    env.CALI_DEBUG === "1" ||
    env.CALI_DEBUG === "true";

  return {
    enabled,
    log(scope, message, data) {
      if (!enabled) return;

      const suffix = data ? ` ${JSON.stringify(data)}` : "";
      console.error(`[cali:${scope}] ${message}${suffix}`);
    },
  };
}

export const debugLogger = createDebugLogger();
