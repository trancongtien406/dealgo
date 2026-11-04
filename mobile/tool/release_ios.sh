#!/usr/bin/env bash
# Release IPA with obfuscation + split debug info, then upload Dart symbols and
# iOS dSYMs to Sentry (org/project in pubspec.yaml `sentry:` block).
#
#   SENTRY_AUTH_TOKEN=... tool/release_ios.sh [extra flutter build args]
#
# The token is read from the environment (or gitignored sentry.properties);
# never commit it. Without a token the IPA is still built and the upload is
# skipped with a warning (crashes then show obfuscated Dart frames).
set -euo pipefail
cd "$(dirname "$0")/.."

SYMBOLS_DIR="build/debug-info"
mkdir -p "$SYMBOLS_DIR"

FLUTTER_BIN="flutter"
if command -v fvm &>/dev/null && [ -f .fvmrc ]; then
  FLUTTER_BIN="fvm flutter"
fi

DART_BIN="dart"
if command -v fvm &>/dev/null && [ -f .fvmrc ]; then
  DART_BIN="fvm dart"
fi

$FLUTTER_BIN build ipa --release \
  --obfuscate \
  --split-debug-info="$SYMBOLS_DIR" \
  --extra-gen-snapshot-options=--save-obfuscation-map="$SYMBOLS_DIR/app.obfuscation-map.json" \
  "$@"

if [[ -n "${SENTRY_AUTH_TOKEN:-}" || -f sentry.properties ]]; then
  # Uploads build/debug-info (Dart) and the dSYMs under build/ios (native).
  SENTRY_ARGS=()
  if [[ -f "$SYMBOLS_DIR/app.obfuscation-map.json" ]]; then
    SENTRY_ARGS+=("--sentry-define=dart_symbol_map_path=$SYMBOLS_DIR/app.obfuscation-map.json")
  fi
  $DART_BIN run sentry_dart_plugin "${SENTRY_ARGS[@]}"
else
  echo "WARN: SENTRY_AUTH_TOKEN not set; Sentry symbol upload skipped." >&2
fi
echo "IPA: build/ios/ipa/  (upload with Transporter or xcrun altool / Xcode)"
