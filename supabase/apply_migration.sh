#!/bin/sh
# Применяет миграцию 003. Требует: supabase link (или psql с DATABASE_URL)

set -e
cd "$(dirname "$0")/.."

if command -v supabase >/dev/null 2>&1; then
  if supabase db push 2>/dev/null; then
    echo "Миграция применена (supabase db push)"
    exit 0
  fi
fi

# Supabase не установлен или проект не привязан — выводим SQL для ручного запуска
echo "Supabase CLI не сконфигурирован. Выполните SQL вручную:"
echo "1. Откройте Supabase Dashboard → SQL Editor"
echo "2. Вставьте и выполните содержимое supabase/migrations/003_cover_url_and_tracks.sql"
echo ""
echo "Или свяжите проект: supabase link"
exit 1
