# Aurix AI Proxy — Cloudflare Worker

Проксирует запросы к OpenAI. Ключ хранится только в Cloudflare (Secret).

## Добавить секрет OPENAI_API_KEY

### Вариант 1: через wrangler

```bash
cd cloudflare_worker
npx wrangler secret put OPENAI_API_KEY
# Введите ключ при запросе
```

### Вариант 2: через Cloudflare Dashboard

1. Откройте [dash.cloudflare.com](https://dash.cloudflare.com)
2. Workers & Pages → **wandering-snow-3f00**
3. Settings → Variables and Secrets
4. Add variable → Secret: `OPENAI_API_KEY`, вставьте ваш OpenAI API ключ

## Запуск

```bash
# Локальная разработка
npx wrangler dev

# Деплой
npx wrangler deploy
```

URL после деплоя: https://wandering-snow-3f00.armtelan1.workers.dev
