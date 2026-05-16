import Anthropic from "@anthropic-ai/sdk";
import { requireAnthropicKey } from "./ical-agent.js";
import { executeTool, anthropicTools, type ToolInput } from "./tools.js";
import { debugLogger, type DebugLogger } from "./debug.js";

export interface ChatSessionOptions {
  apiKey: string;
  instructions: string;
  model?: string;
  onTextDelta?: (delta: string) => void;
  onStatus?: (message: string) => void;
  onResponseStart?: () => void;
  onResponseEnd?: () => void;
  debug?: DebugLogger;
  _client?: Anthropic;
}

const DEFAULT_MODEL = "claude-sonnet-4-6";

export { requireAnthropicKey };

export class ChatSession {
  private messages: Anthropic.MessageParam[] = [];
  private readonly client: Anthropic;
  private readonly debug: DebugLogger;

  constructor(private readonly options: ChatSessionOptions) {
    this.client =
      options._client ?? new Anthropic({ apiKey: options.apiKey });
    this.debug = options.debug ?? debugLogger;
  }

  static connect(options: ChatSessionOptions): ChatSession {
    return new ChatSession(options);
  }

  injectContextMessage(text: string): void {
    this.messages.push({ role: "user", content: text });
  }

  clearHistory(): void {
    this.messages = [];
  }

  close(): void {
    // nothing to close — stateless HTTP sessions
  }

  async sendText(input: string): Promise<string> {
    this.messages.push({ role: "user", content: input });
    this.options.onResponseStart?.();
    const text = await this.runLoop();
    this.options.onResponseEnd?.();
    return text;
  }

  private async runLoop(): Promise<string> {
    while (true) {
      const model = this.options.model ?? DEFAULT_MODEL;
      this.debug.log("chat", "send", { model, messages: this.messages.length });

      const stream = this.client.messages.stream({
        model,
        max_tokens: 8192,
        system: this.options.instructions,
        tools: anthropicTools(),
        tool_choice: { type: "auto" },
        messages: [...this.messages],
      });

      let accumulatedText = "";
      stream.on("text", (delta) => {
        accumulatedText += delta;
        this.options.onTextDelta?.(delta);
      });

      const response = await stream.finalMessage();
      this.debug.log("chat", "recv", {
        stop_reason: response.stop_reason,
        blocks: response.content.length,
      });

      this.messages.push({ role: "assistant", content: response.content });

      if (response.stop_reason === "end_turn") {
        return accumulatedText;
      }

      if (response.stop_reason === "tool_use") {
        if (accumulatedText.trim()) {
          this.options.onStatus?.(accumulatedText.trim());
        }

        const toolUses = response.content.filter(
          (b): b is Anthropic.ToolUseBlock => b.type === "tool_use",
        );

        const toolResults: Anthropic.ToolResultBlockParam[] = [];
        for (const use of toolUses) {
          this.debug.log("chat", "tool call", { name: use.name });
          this.options.onStatus?.(`running ${use.name}...`);
          const output = await executeTool(use.name, use.input as ToolInput);
          this.debug.log("chat", "tool result", {
            name: use.name,
            outputBytes: output.length,
          });
          toolResults.push({
            type: "tool_result",
            tool_use_id: use.id,
            content: output,
          });
        }

        this.messages.push({ role: "user", content: toolResults });
        continue;
      }

      return accumulatedText;
    }
  }
}
