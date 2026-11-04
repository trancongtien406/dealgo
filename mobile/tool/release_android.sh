#!/usr/bin/env bash
# Build release Android App Bundle (AAB) with obfuscation and split debug info for Google Play Console.
# API, Mapbox public token and App Links are handled automatically by backend client-config.
#
# Usage:
#   ./tool/release_android.sh
#   SENTRY_AUTH_TOKEN=... ./tool/release_android.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SYMBOLS_DIR="build/debug-info"
mkdir -p "$SYMBOLS_DIR"

echo "==> Building Android App Bundle (AAB) for Google Play (obfuscated + debug symbols)..."
flutter build appbundle --release \
  --no-pub \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --extra-gen-snapshot-options=--save-obfuscation-map="$SYMBOLS_DIR/app.obfuscation-map.json" \
  "$@"

if [[ -n "${SENTRY_AUTH_TOKEN:-}" || -f sentry.properties ]]; then
  echo "==> Uploading symbols to Sentry..."
  SENTRY_ARGS=()
  if [[ -f "$SYMBOLS_DIR/app.obfuscation-map.json" ]]; then
    SENTRY_ARGS+=("--sentry-define=dart_symbol_map_path=$SYMBOLS_DIR/app.obfuscation-map.json")
  fi
  dart run sentry_dart_plugin "${SENTRY_ARGS[@]}" || echo "WARN: Sentry symbol upload failed." >&2
fi

echo ""
echo "==> BUILD SUCCESSFUL!"
echo "AAB file:     $(pwd)/build/app/outputs/bundle/release/app-release.aab"
echo "Symbols dir:  $(pwd)/$SYMBOLS_DIR (dùng để upload deobfuscation symbols lên Play Console nếu cần)"
