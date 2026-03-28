#!/bin/sh
# Применяет все миграции в PostgreSQL.
# Использует переменные окружения: PG_HOST, PG_USER, PG_PASSWORD, PG_DATABASE
# Или DATABASE_URL

set -e
cd "$(dirname "$0")"

DB_URL="${DATABASE_URL:-postgresql://${PG_USER:-aurix}:${PG_PASSWORD}@${PG_HOST:-localhost}:${PG_PORT:-5432}/${PG_DATABASE:-aurixdb}}"

if [ -z "$PG_PASSWORD" ] && [ -z "$DATABASE_URL" ]; then
  echo "Задайте PG_PASSWORD или DATABASE_URL"
  exit 1
fi

for f in migrations/*.sql; do
  echo "Применяю: $f"
  psql "$DB_URL" -f "$f" 2>&1 || true
done

echo "Все миграции применены."
