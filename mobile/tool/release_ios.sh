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

fvm flutter build ipa --release \
  --obfuscate --split-debug-info=build/debug-info "$@"

if [[ -n "${SENTRY_AUTH_TOKEN:-}" || -f sentry.properties ]]; then
  # Uploads build/debug-info (Dart) and the dSYMs under build/ios (native).
  fvm dart run sentry_dart_plugin
else
  echo "WARN: SENTRY_AUTH_TOKEN not set; Sentry symbol upload skipped." >&2
fi
echo "IPA: build/ios/ipa/  (upload with Transporter or xcrun altool / Xcode)"
