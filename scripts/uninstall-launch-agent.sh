#!/usr/bin/env bash
set -euo pipefail

LABEL="com.focusfollowmouse.app"
PLIST_DST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
INSTALL_DIR="${HOME}/Library/Application Support/FocusFollowMouse"
UID_NUM="$(id -u)"

if [[ -f "${PLIST_DST}" ]]; then
  launchctl bootout "gui/${UID_NUM}/${LABEL}" 2>/dev/null || true
  rm -f "${PLIST_DST}"
  echo "Launch Agent odstraněn."
else
  echo "Launch Agent nebyl nainstalován (${PLIST_DST})."
fi

if [[ -d "${INSTALL_DIR}" ]]; then
  rm -rf "${INSTALL_DIR}"
  echo "Složka aplikace smazána: ${INSTALL_DIR}"
fi
