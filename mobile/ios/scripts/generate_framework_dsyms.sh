#!/bin/sh
set -e

# ==============================================================================
# Generate dSYMs for Embedded Precompiled Binary Frameworks
# ==============================================================================
# Prevents App Store Connect / Xcode Organizer warnings:
# "Upload Symbols Failed: The archive did not include a dSYM for [...] with the UUIDs [...]"
#
# Closed-source and precompiled frameworks (FirebaseAnalytics, GoogleAppMeasurement,
# RecaptchaEnterpriseSDK, Sentry, WebRTC, etc.) do not always include standalone
# dSYM files in SPM or CocoaPods. dsymutil generates the DWARF dSYM bundle matching
# the exact binary UUID that Apple validation requires.
# ==============================================================================

# Only run for Release / Profile builds or when archiving
if [ "${CONFIGURATION}" != "Release" ] && [ "${CONFIGURATION}" != "Profile" ] && [ "${ACTION}" != "install" ]; then
  exit 0
fi

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
DSYMS_DIR="${DWARF_DSYM_FOLDER_PATH}"

echo "[dSYM Generator] Checking embedded frameworks in: ${FRAMEWORKS_DIR}"
echo "[dSYM Generator] DWARF dSYM output directory: ${DSYMS_DIR}"
if [ -n "${ARCHIVE_PATH}" ]; then
  echo "[dSYM Generator] Archive destination: ${ARCHIVE_PATH}/dSYMs"
fi

# Function to generate and sync dSYM for a framework
process_framework() {
  framework_path="$1"
  framework_name=$(basename "${framework_path}" .framework)
  framework_binary="${framework_path}/${framework_name}"

  if [ ! -f "${framework_binary}" ]; then
    return 0
  fi

  # Skip static libraries or non-Mach-O files
  if ! file "${framework_binary}" | grep -q "Mach-O"; then
    return 0
  fi

  target_dsym=""
  if [ -n "${DSYMS_DIR}" ] && [ -d "$(dirname "${DSYMS_DIR}")" ]; then
    mkdir -p "${DSYMS_DIR}"
    target_dsym="${DSYMS_DIR}/${framework_name}.framework.dSYM"
  fi

  archive_dsym=""
  if [ -n "${ARCHIVE_PATH}" ] && [ -d "${ARCHIVE_PATH}" ]; then
    mkdir -p "${ARCHIVE_PATH}/dSYMs"
    archive_dsym="${ARCHIVE_PATH}/dSYMs/${framework_name}.framework.dSYM"
  fi

  # Check if dSYM already exists in both locations
  needs_generation=0
  if [ -n "${target_dsym}" ] && [ ! -d "${target_dsym}" ]; then
    needs_generation=1
  fi
  if [ -n "${archive_dsym}" ] && [ ! -d "${archive_dsym}" ]; then
    needs_generation=1
  fi

  if [ "${needs_generation}" -eq 1 ]; then
    echo "[dSYM Generator] Generating dSYM for ${framework_name}..."
    out_dsym="${target_dsym:-$archive_dsym}"
    if [ -n "${out_dsym}" ]; then
      dsymutil "${framework_binary}" -o "${out_dsym}" 2>/dev/null || true
      if [ -d "${out_dsym}" ]; then
        if [ -n "${archive_dsym}" ] && [ "${out_dsym}" != "${archive_dsym}" ]; then
          cp -Rf "${out_dsym}" "${archive_dsym}" 2>/dev/null || true
        fi
        if [ -n "${target_dsym}" ] && [ "${out_dsym}" != "${target_dsym}" ]; then
          cp -Rf "${out_dsym}" "${target_dsym}" 2>/dev/null || true
        fi
      fi
    fi
  fi
}

if [ -d "${FRAMEWORKS_DIR}" ]; then
  find "${FRAMEWORKS_DIR}" -maxdepth 1 -name "*.framework" | while read -r fw; do
    process_framework "${fw}"
  done
fi

# Also check Archive Products if running in archive context
if [ -n "${ARCHIVE_PATH}" ] && [ -d "${ARCHIVE_PATH}/Products/Applications" ]; then
  find "${ARCHIVE_PATH}/Products/Applications" -name "*.framework" | while read -r fw; do
    process_framework "${fw}"
  done
fi

echo "[dSYM Generator] Done."
exit 0

