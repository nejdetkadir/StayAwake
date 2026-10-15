#!/bin/bash
# Build StayAwake from source and install it. (Prebuilt DMGs are on the GitHub Releases page.)
#   ./install.sh            Build, install to /Applications, allow passwordless pmset, launch
#   ./install.sh build      Build build/StayAwake.app only (no sudo)
#   ./install.sh uninstall  Remove the app, the login item and the sudoers rule
set -euo pipefail
cd "$(dirname "$0")"

APP="/Applications/StayAwake.app"
BUNDLE="build/StayAwake.app"
SUDOERS="/etc/sudoers.d/stayawake"
LABEL="com.nejdetkadirbektas.stayawake"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

stop_app() {
  pkill -x StayAwake 2>/dev/null || true
  for _ in $(seq 50); do pgrep -x StayAwake >/dev/null || return 0; sleep 0.1; done
}

if [ "${1:-}" = "uninstall" ]; then
  echo "Tip: turn off 'Stay Awake' in the menu before uninstalling to restore your sleep settings."
  launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
  stop_app
  rm -f "$AGENT"
  sudo rm -rf "$APP" "$SUDOERS"
  echo "✔ StayAwake removed. Your settings backup (if any) is kept in ~/.stay-awake."
  exit 0
fi

command -v swift >/dev/null || { echo "Swift not found. Install it with: xcode-select --install"; exit 1; }

echo "▸ Building..."
scripts/build-app.sh
[ "${1:-}" = "build" ] && exit 0

echo "▸ Allowing passwordless pmset (only /usr/bin/pmset)..."
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
echo "$(whoami) ALL=(root) NOPASSWD: /usr/bin/pmset" > "$TMP"
if sudo visudo -cf "$TMP" >/dev/null; then
  sudo install -m 0440 -o root -g wheel "$TMP" "$SUDOERS"
else
  echo "Could not validate the sudoers rule. Aborting."
  exit 1
fi

echo "▸ Installing to /Applications..."
stop_app
sudo rm -rf "$APP"
sudo cp -R "$BUNDLE" "$APP"
sudo chown -R "$(whoami)" "$APP"

open "$APP"
echo "✔ Installed. Look for the cup icon in the menu bar (green = awake)."
