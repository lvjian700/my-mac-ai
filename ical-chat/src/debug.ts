export interface DebugLogger {
  enabled: boolean;
  log(scope: string, message: string, data?: Record<string, unknown>): void;
}

let forceEnabled = false;

export function setDebugLoggingEnabled(enabled: boolean): void {
  forceEnabled = enabled;
}

export function createDebugLogger(
  env: NodeJS.ProcessEnv = process.env,
): DebugLogger {
  return {
    get enabled() {
      return isDebugEnabled(env);
    },
    log(scope, message, data) {
      if (!isDebugEnabled(env)) return;

      const suffix = data ? ` ${JSON.stringify(data)}` : "";
      console.error(`[cali:${scope}] ${message}${suffix}`);
    },
  };
}

export const debugLogger = createDebugLogger();

function isDebugEnabled(env: NodeJS.ProcessEnv): boolean {
  return (
    forceEnabled ||
    env.CALI_DEBUG_REALTIME === "1" ||
    env.CALI_DEBUG_REALTIME === "true" ||
    env.CALI_DEBUG === "1" ||
    env.CALI_DEBUG === "true"
  );
}
