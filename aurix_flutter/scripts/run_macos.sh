#!/bin/bash
# Сборка и запуск Aurix на macOS (обходит "Failed to foreground app; open returned 1")

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Debug/aurix_flutter.app"

cd "$PROJECT_DIR"

# Опционально: dart-define из переменных окружения
DART_DEFINES=""
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
  DART_DEFINES="--dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
fi

echo "Building..."
flutter clean
flutter pub get
flutter build macos --debug $DART_DEFINES

echo "Removing quarantine..."
xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true

echo "Launching..."
if open "$APP_PATH" 2>/dev/null; then
  echo "Done."
else
  echo "macOS блокирует запуск. Откройте вручную: Finder → build/... → aurix_flutter.app → Open"
  open -a Finder "$PROJECT_DIR/build/macos/Build/Products/Debug"
fi
