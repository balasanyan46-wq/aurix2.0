# Aurix AI Proxy — Cloudflare Worker

Проксирует запросы к OpenAI и содержит бэкенд-логику Aurix DNK (Artist DNA profiling).

## Необходимые ENV-переменные (Secrets)

| Переменная | Описание |
|---|---|
| `OPENAI_API_KEY` | OpenAI API key (GPT-4o-mini) |
| `AURIX_INTERNAL_KEY` | Internal auth key для `/v1/tools/*` |
| `SUPABASE_URL` | Supabase project URL (e.g. `https://xxx.supabase.co`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key (full access, bypasses RLS) |

### Установка секретов

```bash
cd cloudflare_worker
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put AURIX_INTERNAL_KEY
npx wrangler secret put SUPABASE_URL
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
```

Или через [Cloudflare Dashboard](https://dash.cloudflare.com) → Workers & Pages → **wandering-snow-3f00** → Settings → Variables and Secrets.

## Запуск локально

```bash
cd cloudflare_worker
npm install          # ставит zod и остальные зависимости

# Создай файл .dev.vars с секретами для локальной разработки:
cat > .dev.vars << 'EOF'
OPENAI_API_KEY=sk-...
AURIX_INTERNAL_KEY=your-internal-key
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...
EOF

npx wrangler dev
```

Worker будет доступен на `http://localhost:8787`.

### Тестирование /dnk/finish локально

```bash
# 1. Запусти dev-сервер
npx wrangler dev

# 2. Создай сессию
curl -X POST http://localhost:8787/dnk/start \
  -H "Content-Type: application/json" \
  -d '{"user_id":"YOUR_USER_UUID"}'

# 3. Отправь ответы (пример для scale)
curl -X POST http://localhost:8787/dnk/answer \
  -H "Content-Type: application/json" \
  -d '{"session_id":"SESSION_ID","question_id":"q01_energy_drive","answer_type":"scale","answer_json":{"value":4}}'

# 4. Завершение + профиль
curl -X POST http://localhost:8787/dnk/finish \
  -H "Content-Type: application/json" \
  -d '{"session_id":"SESSION_ID"}'
```

Ответ содержит `axes`, `confidence` (overall + by_axis), `profile_text`, `recommendations`, `prompts`, `tags`, `red_flags`, `inconsistency`.

## Деплой

```bash
npx wrangler deploy
```

URL после деплоя: `https://wandering-snow-3f00.armte1an1.workers.dev`

## Endpoints

### AI Chat
- `POST /api/ai/chat` — общий AI-чат (rate limited)

### AI Cover generator
- `POST /api/ai/cover` — генерация PNG обложки (rate limited)
  - Возвращает `{ ok: true, b64_png: "<base64>", meta: {...} }`
  - Нужен `OPENAI_API_KEY`

### AI Tools (Internal)
- `POST /v1/tools/{tool-name}` — AI-инструменты (требует `X-AURIX-INTERNAL-KEY`)

### Aurix DNK
- `POST /dnk/start` — создание DNK-сессии
  - Body: `{ "user_id": "<uuid>" }`
  - Response: `{ "session_id": "<uuid>", "questions": [...] }`

- `POST /dnk/answer` — сохранение ответа + получение followup
  - Body: `{ "session_id": "<uuid>", "question_id": "s1", "answer_type": "scale", "answer_json": { "value": 4 } }`
  - Response: `{ "ok": true, "followup": null | <question_obj> }`

- `POST /dnk/finish` — запуск скоринга + LLM-анализа
  - Body: `{ "session_id": "<uuid>" }`
  - Response: `{ "axes": {...}, "confidence": {...}, "profile_text": "...", "recommendations": {...}, "prompts": {...}, ... }`

## SQL миграция

Перед использованием DNK запусти миграцию в Supabase:

```bash
# Через Dashboard: SQL Editor → вставить содержимое:
# supabase/migrations/027_dnk_tables.sql
```

## Архитектура DNK

1. **Flutter** показывает вопросы из встроенного банка (25 + до 10 адаптивных)
2. Ответы сохраняются через Worker → Supabase (`dnk_answers`)
3. `/dnk/finish` выполняет:
   - Детерминированный скоринг по весам вопросов → `axes_base`
   - LLM (`extract_features`) с **Zod-валидацией + auto-repair** → теги, корректировки осей, red flags
   - Объединение: `axes_final = clamp(axes_base + adjustments, 0, 100)`
   - Подсчёт `inconsistency` по парам противоположных вопросов (0..1)
   - `confidence.overall` = 0.92 − penalties (inconsistency, red_flags, duration); clamp [0.30..0.95]
   - `confidence.by_axis` = overall с дополнительными штрафами при высокой inconsistency
   - LLM (`generate_profile`) с **Zod-валидацией + auto-repair** → профиль, рекомендации, промпты
4. Результат сохраняется в `dnk_results` и возвращается клиенту

## LLM Auto-Repair

Если LLM вернул JSON, который не прошёл Zod-валидацию (лишние ключи, строковые числа, невалидный `tempo_range_bpm` и т.п.), Worker автоматически:

1. Отправляет сломанный JSON в отдельный LLM-вызов с `REPAIR_SYSTEM_PROMPT`
2. Repair-бот возвращает исправленный JSON строго по схеме
3. Если repair не помог — продолжаются обычные ретраи

В ответе `/dnk/finish` нет прямого поля `repaired`, но в логах Worker видно:
```
[DNK] extract_features: repaired=true, attempts=2
[DNK] generate_profile: repaired=false, attempts=1
```

### Отключение auto-repair (для дебага)

В `handlers.ts` в вызовах `callLLMWithAutoRepair` добавь `enableRepair: false`:
```typescript
const extractResult = await callLLMWithAutoRepair({
  ...
  enableRepair: false,  // отключает auto-repair, оставляет только ретраи
});
```

## Зависимости

| Пакет | Назначение |
|---|---|
| `zod` | Валидация JSON-ответов LLM (schemas.ts) |
| `@cloudflare/workers-types` | TypeScript типы для Workers runtime |
| `wrangler` | CLI для деплоя |
