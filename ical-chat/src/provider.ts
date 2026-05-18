import Anthropic from "@anthropic-ai/sdk";

export interface Provider {
  client: Anthropic;
  orchestratorModel: string;
  subAgentModel: string;
}

export function requireAnthropicKey(env: NodeJS.ProcessEnv = process.env): string {
  const key = env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY is required");
  return key;
}

let cached: Provider | undefined;

export async function getProvider(): Promise<Provider> {
  if (cached) return cached;
  try {
    const local = await import("./provider.local.js");
    cached = local.createProvider();
  } catch {
    cached = {
      client: new Anthropic({ apiKey: requireAnthropicKey() }),
      orchestratorModel: "claude-sonnet-4-6",
      subAgentModel: "claude-haiku-4-5-20251001",
    };
  }
  return cached;
}
