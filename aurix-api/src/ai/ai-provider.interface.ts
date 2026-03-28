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
