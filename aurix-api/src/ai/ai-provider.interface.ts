// ── AI generation types ──────────────────────────────────────

export type AiGenerationType = 'text' | 'image' | 'video' | 'audio';

/** Centralized provider configuration — single source of truth */
export const EDEN_PROVIDERS: Record<AiGenerationType, string> = {
  text: 'deepseek,qwen,google',
  image: 'stability,google',
  video: 'runway',
  audio: 'google,amazon',
};

export const EDEN_ENDPOINTS: Record<AiGenerationType, string> = {
  text: 'https://api.edenai.run/v2/text/chat',
  image: 'https://api.edenai.run/v2/image/generation',
  video: 'https://api.edenai.run/v2/video/generation',
  audio: 'https://api.edenai.run/v2/audio/text_to_speech',
};

/** Credit cost per generation type */
export const GENERATION_CREDIT_ACTIONS: Record<AiGenerationType, string> = {
  text: 'ai_chat',
  image: 'ai_cover',
  video: 'ai_video',
  audio: 'ai_audio',
};

// ── Chat types (text mode) ───────────────────────────────────

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export type AiMode = 'chat' | 'lyrics' | 'ideas' | 'reels' | 'dnk' | 'dnk_full' | 'analyze';

export interface ChatParams {
  message: string;
  mode?: AiMode;
  history?: Array<{ role: string; content: string }>;
  /** Injected user context (profile, tracks, DNK) — appended to system prompt */
  contextPrompt?: string;
}

export interface AiProvider {
  chat(params: ChatParams): Promise<string>;
}

// ── Unified generate types ───────────────────────────────────

export interface GenerateParams {
  type: AiGenerationType;
  prompt: string;
  userId?: string;
  /** Image resolution (default: 1024x1024) */
  resolution?: string;
  /** Number of images */
  numImages?: number;
  /** Audio language (default: ru) */
  language?: string;
  /** Audio voice option */
  voice?: string;
}

/** Normalized response — always the same shape regardless of type */
export interface GenerateResult {
  type: AiGenerationType;
  /** Generated text (type=text) or URL (type=image/video/audio) */
  content: string;
  /** Which provider delivered the result */
  provider: string;
  /** Full provider response for debugging */
  raw: any;
}

// ── Request log entry ────────────────────────────────────────

export interface AiRequestLog {
  userId?: string;
  type: AiGenerationType;
  provider: string;
  success: boolean;
  latencyMs: number;
  error?: string;
}
