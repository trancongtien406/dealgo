#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION=3.47.7
FLUTTER_SHA256=af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230
FLUTTER_ROOT=/opt/flutter
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

# cmdline-tools build published on the Android Studio "command line tools only" table.
CMDLINE_TOOLS_BUILD=15859902
CMDLINE_TOOLS_SHA256=4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip"

# Flutter 3.47.7 FlutterExtension plus AGP 9.1 defaults. Do not bump independently of the app.
ANDROID_SDK_ROOT=/opt/android-sdk
ANDROID_PLATFORM=android-36
ANDROID_BUILD_TOOLS=36.0.0
ANDROID_NDK=28.2.13676358
JAVA_HOME_DEFAULT=/usr/lib/jvm/java-21-openjdk-amd64

if [[ -x "${FLUTTER_ROOT}/bin/flutter" ]] && "${FLUTTER_ROOT}/bin/flutter" --version 2>/dev/null | grep -q "Flutter ${FLUTTER_VERSION} "; then
  echo "Flutter ${FLUTTER_VERSION} already installed"
else
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils zip libglu1-mesa
  tmp="$(mktemp)"
  curl -fsSL "$FLUTTER_URL" -o "$tmp"
  echo "${FLUTTER_SHA256}  ${tmp}" | sha256sum -c -
  sudo rm -rf "$FLUTTER_ROOT"
  sudo tar -C /opt -xJf "$tmp"
  rm -f "$tmp"
  sudo chown -R "$(id -un)":"$(id -gn)" "$FLUTTER_ROOT"
fi

sudo ln -sfn "${FLUTTER_ROOT}/bin/flutter" /usr/local/bin/flutter
sudo ln -sfn "${FLUTTER_ROOT}/bin/dart" /usr/local/bin/dart

if ! git config --global --get-all safe.directory 2>/dev/null | grep -qx "$FLUTTER_ROOT"; then
  git config --global --add safe.directory "$FLUTTER_ROOT"
fi

if [[ ! -x "${JAVA_HOME_DEFAULT}/bin/java" ]]; then
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends openjdk-21-jdk-headless ca-certificates curl unzip
fi

export JAVA_HOME="$JAVA_HOME_DEFAULT"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_SDK_ROOT
export PATH="${JAVA_HOME}/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator:${PATH}"

sudo tee /etc/profile.d/dealgo-android.sh >/dev/null <<EOF
export JAVA_HOME=${JAVA_HOME_DEFAULT}
export ANDROID_HOME=${ANDROID_SDK_ROOT}
export ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}
export PATH="\${JAVA_HOME}/bin:\${ANDROID_HOME}/cmdline-tools/latest/bin:\${ANDROID_HOME}/platform-tools:\${ANDROID_HOME}/emulator:\${PATH}"
EOF
sudo chmod 644 /etc/profile.d/dealgo-android.sh

if [[ ! -x "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager" ]]; then
  work="$(mktemp -d)"
  curl -fsSL "$CMDLINE_TOOLS_URL" -o "${work}/cmdtools.zip"
  echo "${CMDLINE_TOOLS_SHA256}  ${work}/cmdtools.zip" | sha256sum -c -
  unzip -q "${work}/cmdtools.zip" -d "$work"
  sudo mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools"
  sudo rm -rf "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
  sudo mv "${work}/cmdline-tools" "${ANDROID_SDK_ROOT}/cmdline-tools/latest"
  rm -rf "$work"
  sudo chown -R "$(id -un)":"$(id -gn)" "$ANDROID_SDK_ROOT"
fi

sdkmanager_bin="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager"
set +e
yes | "$sdkmanager_bin" --sdk_root="$ANDROID_SDK_ROOT" --licenses
license_status=$?
set -e
if [[ "$license_status" -ne 0 && "$license_status" -ne 141 ]]; then
  echo "sdkmanager --licenses failed with status ${license_status}" >&2
  exit "$license_status"
fi

"$sdkmanager_bin" --sdk_root="$ANDROID_SDK_ROOT" --install \
  "platform-tools" \
  "platforms;${ANDROID_PLATFORM}" \
  "build-tools;${ANDROID_BUILD_TOOLS}" \
  "ndk;${ANDROID_NDK}" \
  "emulator"

sudo ln -sfn "${ANDROID_SDK_ROOT}/platform-tools/adb" /usr/local/bin/adb
sudo ln -sfn "${sdkmanager_bin}" /usr/local/bin/sdkmanager
sudo ln -sfn "${ANDROID_SDK_ROOT}/emulator/emulator" /usr/local/bin/emulator

if [[ -e /dev/kvm ]]; then
  kvm_gid="$(stat -c '%g' /dev/kvm)"
  if ! getent group "$kvm_gid" >/dev/null; then
    sudo groupadd -g "$kvm_gid" kvm
  fi
  kvm_group="$(getent group "$kvm_gid" | cut -d: -f1)"
  if [[ -n "$kvm_group" ]]; then
    sudo usermod -aG "$kvm_group" "$(id -un)"
  fi
fi

flutter config --no-analytics
flutter config --android-sdk "$ANDROID_SDK_ROOT"
flutter config --jdk-dir "$JAVA_HOME"
dart --disable-analytics

# Node major comes from /workspace/.nvmrc (same file CI reads via node-version-file).
NODE_MAJOR="$(tr -d '[:space:]v' < /workspace/.nvmrc)"
NODE_ROOT="/opt/node-v${NODE_MAJOR}"
if ! "${NODE_ROOT}/bin/node" -v 2>/dev/null | grep -q "^v${NODE_MAJOR}\."; then
  node_index="https://nodejs.org/dist/latest-v${NODE_MAJOR}.x"
  node_sums="$(curl -fsSL "${node_index}/SHASUMS256.txt")"
  node_tarball="$(awk '/linux-x64\.tar\.xz$/ {print $2; exit}' <<<"$node_sums")"
  node_sha="$(awk -v f="$node_tarball" '$2 == f {print $1}' <<<"$node_sums")"
  tmp="$(mktemp)"
  curl -fsSL "${node_index}/${node_tarball}" -o "$tmp"
  echo "${node_sha}  ${tmp}" | sha256sum -c -
  sudo rm -rf "$NODE_ROOT"
  sudo mkdir -p "$NODE_ROOT"
  sudo tar -C "$NODE_ROOT" --strip-components=1 -xJf "$tmp"
  rm -f "$tmp"
fi
echo "export PATH=\"${NODE_ROOT}/bin:\${PATH}\"" | sudo tee /etc/profile.d/dealgo-node.sh >/dev/null
sudo chmod 644 /etc/profile.d/dealgo-node.sh
export PATH="${NODE_ROOT}/bin:${PATH}"

# Local Postgres + Redis for the API when Docker is unavailable (start script prefers Docker).
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  if ! command -v pg_ctlcluster >/dev/null 2>&1 || ! command -v redis-server >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends postgresql redis-server
  fi
fi

cd /workspace
npm ci --no-audit --no-fund --prefix backend
npm ci --no-audit --no-fund --prefix website
(
  cd mobile
  flutter pub get
)
