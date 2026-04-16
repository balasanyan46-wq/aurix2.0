require('dotenv').config();
const express = require('express');
const axios = require('axios');
const cors = require('cors');

const app = express();
app.use(cors({
  origin: ['https://aurixmusic.ru', 'http://localhost:3000'],
  methods: ['GET', 'POST'],
}));
app.use(express.json({ limit: '2mb' }));

const PORT = process.env.PORT || 3000;
const SECRET = process.env.GATEWAY_SECRET || '';

// ── Auth middleware ──────────────────────────────────────
function auth(req, res, next) {
  if (!SECRET) {
    console.error('GATEWAY_SECRET not set — rejecting request');
    return res.status(503).json({ success: false, error: 'gateway not configured' });
  }
  const token = req.headers['x-gateway-secret'] || req.headers.authorization?.replace('Bearer ', '');
  if (token !== SECRET) return res.status(401).json({ success: false, error: 'unauthorized' });
  next();
}

// ── Provider configs ────────────────────────────────────
const providers = {
  deepseek: {
    url: 'https://api.deepseek.com/chat/completions',
    key: () => process.env.DEEPSEEK_API_KEY,
    model: 'deepseek-chat',
  },
  mistral: {
    url: 'https://api.mistral.ai/v1/chat/completions',
    key: () => process.env.MISTRAL_API_KEY,
    model: 'mistral-small-latest',
  },
  anthropic: {
    url: 'https://api.anthropic.com/v1/messages',
    key: () => process.env.ANTHROPIC_API_KEY,
    model: 'claude-haiku-4-5-20251001',
    isAnthropic: true,
  },
  openai: {
    url: 'https://api.openai.com/v1/chat/completions',
    key: () => process.env.OPENAI_API_KEY,
    model: 'gpt-4o-mini',
  },
  openrouter: {
    url: 'https://openrouter.ai/api/v1/chat/completions',
    key: () => process.env.OPENROUTER_API_KEY,
    model: 'deepseek/deepseek-chat',
  },
};

// ── Call a single provider ──────────────────────────────
async function callProvider(name, messages, opts = {}) {
  const p = providers[name];
  if (!p || !p.key()) return null;

  const timeout = opts.timeout || 30000;
  const maxTokens = opts.max_tokens || 2000;
  const temperature = opts.temperature ?? 0.7;

  try {
    if (p.isAnthropic) {
      // Anthropic uses different API format
      const systemMsg = messages.find(m => m.role === 'system')?.content || '';
      const userMsgs = messages.filter(m => m.role !== 'system');

      const { data } = await axios.post(p.url, {
        model: opts.model || p.model,
        max_tokens: maxTokens,
        temperature,
        system: systemMsg,
        messages: userMsgs,
      }, {
        headers: {
          'x-api-key': p.key(),
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        timeout,
      });

      const text = data.content?.[0]?.text || '';
      return { provider: name, text, model: data.model, usage: data.usage };
    }

    // OpenAI-compatible format (DeepSeek, Mistral, OpenAI, OpenRouter)
    const headers = {
      'Authorization': `Bearer ${p.key()}`,
      'Content-Type': 'application/json',
    };
    if (name === 'openrouter') {
      headers['HTTP-Referer'] = 'https://aurixmusic.ru';
      headers['X-Title'] = 'AURIX';
    }

    const { data } = await axios.post(p.url, {
      model: opts.model || p.model,
      messages,
      max_tokens: maxTokens,
      temperature,
    }, { headers, timeout });

    const text = data.choices?.[0]?.message?.content || '';
    return { provider: name, text, model: data.model, usage: data.usage };

  } catch (err) {
    const msg = err.response?.data?.error?.message || err.message || 'unknown';
    console.error(`[${name}] FAIL: ${msg}`);
    return null;
  }
}

// ── POST /ai/chat — main endpoint ──────────────────────
app.post('/ai/chat', auth, async (req, res) => {
  const { messages, prompt, system, max_tokens, temperature, model, preferred_providers, timeout: reqTimeout } = req.body;

  // Build messages array
  let msgs;
  if (messages && Array.isArray(messages)) {
    msgs = messages;
  } else {
    msgs = [];
    if (system) msgs.push({ role: 'system', content: system });
    msgs.push({ role: 'user', content: prompt || '' });
  }

  if (!msgs.length || !msgs.some(m => m.role === 'user')) {
    return res.status(400).json({ success: false, error: 'prompt or messages required' });
  }

  // Provider priority: preferred → all available (only try providers with keys)
  const defaultOrder = ['openai', 'deepseek', 'anthropic', 'mistral', 'openrouter'];
  const order = preferred_providers && preferred_providers.length
    ? [...preferred_providers, ...defaultOrder.filter(p => !preferred_providers.includes(p))]
    : defaultOrder;

  const perProviderTimeout = Math.min(reqTimeout || 45000, 120000);
  const opts = { max_tokens: max_tokens || 2000, temperature: temperature ?? 0.7, model, timeout: perProviderTimeout };

  for (const name of order) {
    const result = await callProvider(name, msgs, opts);
    if (result && result.text) {
      console.log(`[OK] ${name} (${result.model}) ${result.text.length} chars`);
      return res.json({
        success: true,
        result: result.text,
        provider: result.provider,
        model: result.model,
        usage: result.usage,
      });
    }
  }

  // All failed
  console.error('[FAIL] All providers failed');
  res.status(502).json({ success: false, error: 'All AI providers failed' });
});

// ── POST /ai/image — image generation proxy ────────────
app.post('/ai/image', auth, async (req, res) => {
  const { prompt, model, size } = req.body;
  if (!prompt) return res.status(400).json({ success: false, error: 'prompt required' });

  // Try OpenAI DALL-E
  if (process.env.OPENAI_API_KEY) {
    try {
      const { data } = await axios.post('https://api.openai.com/v1/images/generations', {
        model: model || 'dall-e-3',
        prompt,
        n: 1,
        size: size || '1024x1024',
      }, {
        headers: { 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
        timeout: 60000,
      });
      const url = data.data?.[0]?.url;
      if (url) return res.json({ success: true, url, provider: 'openai' });
    } catch (err) {
      console.error(`[image/openai] FAIL: ${err.message}`);
    }
  }

  // Try OpenRouter
  if (process.env.OPENROUTER_API_KEY) {
    try {
      const { data } = await axios.post('https://openrouter.ai/api/v1/images/generations', {
        model: model || 'dall-e-3',
        prompt,
        n: 1,
        size: size || '1024x1024',
      }, {
        headers: { 'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`, 'Content-Type': 'application/json' },
        timeout: 60000,
      });
      const url = data.data?.[0]?.url;
      if (url) return res.json({ success: true, url, provider: 'openrouter' });
    } catch (err) {
      console.error(`[image/openrouter] FAIL: ${err.message}`);
    }
  }

  res.status(502).json({ success: false, error: 'Image generation failed' });
});

// ── Telegram Bot ───────────────────────────────────────

const TG_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '';
const TG_CHAT_ID = process.env.TELEGRAM_CHAT_ID || '';

app.post('/telegram/send', auth, async (req, res) => {
  if (!TG_TOKEN) return res.status(500).json({ success: false, error: 'TELEGRAM_BOT_TOKEN not set' });
  const { text, chat_id, parse_mode } = req.body;
  if (!text) return res.status(400).json({ success: false, error: 'text required' });

  try {
    const { data } = await axios.post(`https://api.telegram.org/bot${TG_TOKEN}/sendMessage`, {
      chat_id: chat_id || TG_CHAT_ID,
      text,
      parse_mode: parse_mode || 'Markdown',
    }, { timeout: 10000 });
    res.json({ success: true, result: data.result });
  } catch (err) {
    console.error(`[telegram/send] FAIL: ${err.message}`);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/telegram/get-updates', auth, async (req, res) => {
  if (!TG_TOKEN) return res.status(500).json({ success: false, error: 'TELEGRAM_BOT_TOKEN not set' });
  const { offset } = req.body;

  try {
    const { data } = await axios.get(`https://api.telegram.org/bot${TG_TOKEN}/getUpdates`, {
      params: { offset: offset || 0, timeout: 1, limit: 20 },
      timeout: 10000,
    });
    res.json({ success: true, result: data.result || [] });
  } catch (err) {
    console.error(`[telegram/get-updates] FAIL: ${err.message}`);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── GET /health ─────────────────────────────────────────
app.get('/health', (req, res) => {
  const available = Object.entries(providers)
    .filter(([_, p]) => p.key())
    .map(([name]) => name);

  res.json({
    status: 'ok',
    service: 'aurix-ai-gateway',
    version: '1.0.0',
    providers: available,
    uptime: Math.round(process.uptime()),
  });
});

// ── Start ───────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  const available = Object.entries(providers).filter(([_, p]) => p.key()).map(([n]) => n);
  console.log(`AURIX AI Gateway running on port ${PORT}`);
  console.log(`Available providers: ${available.join(', ') || 'NONE — add API keys to .env'}`);
});
