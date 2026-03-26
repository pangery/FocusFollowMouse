#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.focusfollowmouse.app"
INSTALL_DIR="${HOME}/Library/Application Support/FocusFollowMouse"
BINARY="${INSTALL_DIR}/FocusFollowMouse"
PLIST_SRC="${ROOT}/scripts/${LABEL}.plist"
PLIST_DST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

echo "→ Building release…"
(cd "${ROOT}" && swift build -c release)

mkdir -p "${INSTALL_DIR}"
cp "${ROOT}/.build/release/FocusFollowMouse" "${BINARY}"
chmod +x "${BINARY}"

echo "→ Installing Launch Agent…"
sed "s|__BINARY_PATH__|${BINARY}|g" "${PLIST_SRC}" > "${PLIST_DST}"

UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/${UID_NUM}" "${PLIST_DST}"

echo ""
echo "Hotovo. Aplikace poběží po každém přihlášení z:"
echo "  ${BINARY}"
echo ""
echo "Poznámka: v Soukromí → Dostupnost povol tuto binárku (nebo ji jednou spusť ručně a macOS nabídne oprávnění)."
echo "Odinstalace: ${ROOT}/scripts/uninstall-launch-agent.sh"
