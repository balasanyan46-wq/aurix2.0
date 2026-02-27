import type { z } from "zod";
import type { LLMProvider } from "./types";

const MAX_VALIDATION_RETRIES = 2;

/**
 * Call LLM and validate response against a Zod schema.
 * Retries on JSON parse errors or Zod validation failures (up to maxRetries).
 * On final failure, throws with context.
 */
export async function callLLMValidated<T>(
  provider: LLMProvider,
  systemPrompt: string,
  userPayload: string,
  schema: z.ZodType<T>,
  maxRetries = MAX_VALIDATION_RETRIES
): Promise<T> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const raw = await provider.generateJSON(systemPrompt, userPayload);

      // provider.generateJSON already does JSON.parse, but raw could be
      // a string if the LLM returned a JSON-encoded string wrapper
      const obj = typeof raw === "string" ? JSON.parse(raw) : raw;

      const result = schema.parse(obj);
      return result;
    } catch (e: any) {
      lastError = e;

      if (e?.name === "ZodError") {
        const issues = e.issues?.slice(0, 3).map((i: any) =>
          `${i.path.join(".")}: ${i.message}`
        ).join("; ");
        console.error(
          `[DNK] Zod validation failed (attempt ${attempt + 1}/${maxRetries + 1}): ${issues}`
        );
      } else if (e instanceof SyntaxError) {
        console.error(
          `[DNK] JSON parse failed (attempt ${attempt + 1}/${maxRetries + 1}): ${e.message}`
        );
      } else {
        console.error(
          `[DNK] LLM call failed (attempt ${attempt + 1}/${maxRetries + 1}): ${e.message ?? e}`
        );
      }

      if (attempt < maxRetries) {
        continue;
      }
    }
  }

  throw lastError ?? new Error("LLM validated call failed after retries");
}
