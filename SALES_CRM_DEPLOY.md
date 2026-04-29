# Sales CRM Pipeline — деплой-runbook

Этот документ — пошаговая инструкция для накатывания PR #1 (Sales CRM) на
production. Выполняется один раз, последовательно. Если что-то падает —
не идти дальше до устранения.

## Pre-flight (на твоей машине)

```bash
# 1) PR влит в main
gh pr view 1 --json state -q .state   # должно быть MERGED

# 2) main обновлён локально
git checkout main && git pull

# 3) Бэкенд собирается
cd aurix-api && npm install && npx tsc --noEmit && npx nest build

# 4) Flutter web собирается
cd ../aurix_flutter && flutter pub get && flutter build web --release
```

## Шаг 1: Бэкап БД (обязательно)

```bash
# На VPS / build-машине
DATABASE_URL=postgresql://... pg_dump > /tmp/aurix_backup_pre_sales_crm_$(date +%Y%m%d_%H%M%S).sql
ls -lah /tmp/aurix_backup_*.sql   # убедись что файл не пустой
```

## Шаг 2: Накатить миграции (8 файлов)

```bash
cd /path/to/aurix2.0/supabase
DATABASE_URL=postgresql://... ./apply_migration.sh 2>&1 | tee /tmp/sales_crm_migrate.log
```

После выполнения проверь, что нет ошибок (кроме `IF EXISTS`/`IF NOT EXISTS` warnings — они нормальные):

```bash
grep -iE "error|fatal" /tmp/sales_crm_migrate.log | grep -v "IF NOT EXISTS\|IF EXISTS"
# должно быть пусто
```

Применятся 8 новых миграций:
- `088_extended_admin_roles` — 8 ролей + role_permissions seed
- `089_lead_scoring` — profiles.lead_score / lead_bucket
- `090_leads` — pipeline-таблица leads
- `091_conversion_funnel_view` — view артистической воронки
- `092_ai_sales_signals` — AI sales signals cache
- `093_notifications_types_sales` — расширение CHECK constraint
- `094_offer_funnel` — view offer→payment
- `095_message_templates` — A/B шаблоны + seed

## Шаг 3: Назначить super_admin

⚠️ **Без этого никто не сможет менять роли**.

```sql
-- Замени email на свой
UPDATE users SET role = 'super_admin' WHERE email = 'your_admin@example.com';
SELECT id, email, role FROM users WHERE role = 'super_admin';
-- должна быть хотя бы одна строка
```

## Шаг 4: Деплой бэкенда

```bash
# Скопировать собранный код на VPS
rsync -avz --exclude=node_modules aurix-api/ vps:/opt/aurix-api/

# На VPS
cd /opt/aurix-api && npm ci --omit=dev && npx nest build && pm2 restart aurix-api
pm2 logs aurix-api --lines 50   # убедись что нет crash'ей
```

Что искать в логах:
- ✅ `PostgreSQL pool initialized`
- ✅ `Nest application successfully started`
- ⚠️ Если видишь `Cannot find provider LeadsService` — не накатили миграции, или DI порядок поломан.

## Шаг 5: Деплой Flutter web

```bash
# На build-машине
cd aurix_flutter && flutter build web --release

# Скопировать
rsync -avz build/web/ vps:/var/www/aurix-admin/

# Если веб-сервер кэширует — почистить (Cloudflare и т.д.)
```

## Шаг 6: Smoke test

Открой админку → должны появиться **24 вкладки** (было 22, добавились
«Что делать», «Leads», «Воронка», «Выручка»).

API smoke (от лица super_admin'а; <TOKEN> — JWT из cookie):

```bash
TOKEN="..."

# Revenue dashboard — все нули — норма для пустой БД
curl -s -H "Authorization: Bearer $TOKEN" https://api.example.com/admin/revenue | jq '.mrr_rub, .conversion_to_paid_pct'

# Action Center — список задач
curl -s -H "Authorization: Bearer $TOKEN" https://api.example.com/admin/action-center | jq '.total, .possible_revenue_total'

# Conversion funnel
curl -s -H "Authorization: Bearer $TOKEN" https://api.example.com/admin/conversion | jq '.steps'

# Leads
curl -s -H "Authorization: Bearer $TOKEN" https://api.example.com/admin/leads | jq '.count'

# Offer funnel — пустой пока нет offer_sent
curl -s -H "Authorization: Bearer $TOKEN" https://api.example.com/admin/offer-funnel | jq '.total'

# Sanity: dangerous action без confirm — должно вернуть 400
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{}' https://api.example.com/admin/users/1/block | jq
# Ожидаемо: { "ok": false, "error": "confirmation_required", ... }

# Sanity: с confirm — должно работать
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"confirmed":true,"reason":"smoke test"}' https://api.example.com/admin/users/1/block | jq
# Ожидаемо: { "ok": true, "status": "suspended" }  (но user 1 заблокируется!)
# → не делай этого на реальном юзере, либо потом разблокируй
```

## Шаг 7: Проверка cron (через 60 минут после деплоя)

```sql
SELECT action, created_at, details
  FROM admin_logs
 WHERE action LIKE 'cron_%'
   AND created_at >= now() - interval '2 hours'
 ORDER BY created_at DESC;
```

Должны появиться:
- `cron_lead_scoring_recalc` — раз в 30 минут
- `cron_next_action_refresh` — раз в час
- `cron_ai_sales_refresh` — раз в 4 часа
- `cron_leads_sweep_stale` — раз в день в 03:00 (увидишь только на следующий день)

## Откат (если всё плохо)

```bash
# 1) Восстановить БД из бэкапа
DATABASE_URL=postgresql://... psql < /tmp/aurix_backup_pre_sales_crm_*.sql

# 2) git revert PR
git revert -m 1 <merge_commit_sha> && git push

# 3) Передеплоить старую версию бэкенда
pm2 restart aurix-api
```

## Чек-лист для команды

- [ ] Бэкап БД сделан и проверен
- [ ] Миграции 088-095 накатились без ошибок
- [ ] Super_admin назначен (хотя бы один)
- [ ] Бэкенд задеплоен, в логах нет crash'ей
- [ ] Flutter web задеплоен, видны 24 вкладки
- [ ] Smoke API проверен (revenue, action-center, conversion, leads, offer-funnel)
- [ ] Sanity check dangerous action (block без confirm → 400)
- [ ] Через 60 минут проверены cron записи в admin_logs
- [ ] Команда уведомлена о новых ролях (support/moderator/finance_admin/analyst/super_admin)
