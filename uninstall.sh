#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMED_DIR="$HOME/.config/omarchy/themed"
HOOKS_DIR="$HOME/.config/omarchy/hooks"
ZELLIJ_CONFIG="$HOME/.config/zellij/config.kdl"
OLD_THEME_FILE="$HOME/.config/zellij/themes/omarchy.kdl"
START_MARKER="// --- omarchy-zellij-theme (start) ---"
END_MARKER="// --- omarchy-zellij-theme (end) ---"
LAUNCHER_TARGET="$HOME/.local/bin/zellij-launcher"
DESKTOP_TARGET="$HOME/.local/share/applications/zellij.desktop"
SESSION_START_MARKER="# --- omarchy-zellij-theme session (start) ---"
SESSION_END_MARKER="# --- omarchy-zellij-theme session (end) ---"

echo "=== omarchy-zellij-theme uninstaller ==="

remove_session_alias() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0
  grep -qF "$SESSION_START_MARKER" "$rc" || return 0
  awk -v start="$SESSION_START_MARKER" -v end="$SESSION_END_MARKER" '
    $0 == start { skip = 1; next }
    $0 == end   { skip = 0; next }
    !skip
  ' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
}

# 1. Remove template symlink
if [[ -L "$THEMED_DIR/zellij.kdl.tpl" ]]; then
  rm "$THEMED_DIR/zellij.kdl.tpl"
  echo "[1/6] Removed template symlink."
else
  echo "[1/6] Template symlink not found, skipping."
fi

# 2. Remove hook
if [[ -L "$HOOKS_DIR/theme-set.d/omarchy-zellij-theme" || -f "$HOOKS_DIR/theme-set.d/omarchy-zellij-theme" ]]; then
  rm "$HOOKS_DIR/theme-set.d/omarchy-zellij-theme"
  echo "[2/6] Removed theme-set.d hook."
elif [[ -f "$HOOKS_DIR/theme-set" ]]; then
  if grep -q "omarchy-zellij-theme integration" "$HOOKS_DIR/theme-set" 2>/dev/null; then
    sed -i '/# --- omarchy-zellij-theme integration (start) ---/,/# --- omarchy-zellij-theme integration (end) ---/d' "$HOOKS_DIR/theme-set"
    echo "[2/6] Removed Zellij integration from existing hook."
  elif grep -q "omarchy-zellij" "$HOOKS_DIR/theme-set" 2>/dev/null; then
    rm "$HOOKS_DIR/theme-set"
    echo "[2/6] Removed theme-set hook."
  else
    echo "[2/6] Hook doesn't contain our integration, skipping."
  fi
else
  echo "[2/6] No theme-set hook found, skipping."
fi

# 3. Comment out theme in Zellij config
if [[ -f "$ZELLIJ_CONFIG" ]] && grep -q '^theme "omarchy"' "$ZELLIJ_CONFIG" 2>/dev/null; then
  sed -i 's|^theme "omarchy"|// theme "omarchy"|' "$ZELLIJ_CONFIG"
  echo "[3/6] Commented out theme in Zellij config."
else
  echo "[3/6] Theme not set in Zellij config, skipping."
fi

# 4. Remove inline theme block from config.kdl
if [[ -f "$ZELLIJ_CONFIG" ]] && grep -qF "$START_MARKER" "$ZELLIJ_CONFIG" 2>/dev/null; then
  sed -i "\%${START_MARKER}%,\%${END_MARKER}%d" "$ZELLIJ_CONFIG"
  echo "[4/6] Removed inline theme block from config.kdl."
else
  echo "[4/6] No inline theme block found, skipping."
fi

# 5. Clean up old theme file from previous approach
if [[ -f "$OLD_THEME_FILE" ]]; then
  rm "$OLD_THEME_FILE"
  echo "[5/6] Removed old theme file ($OLD_THEME_FILE)."
else
  echo "[5/6] No old theme file to clean up."
fi

# 6. Remove the fixed-session launcher and shell alias
if [[ -L "$LAUNCHER_TARGET" || -f "$LAUNCHER_TARGET" ]]; then
  rm "$LAUNCHER_TARGET"
  echo "[6/6] Removed zellij launcher."
else
  echo "[6/6] Zellij launcher not found, skipping."
fi
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  remove_session_alias "$rc"
done
if [[ -f "$DESKTOP_TARGET" ]] && grep -qF "$LAUNCHER_TARGET" "$DESKTOP_TARGET" 2>/dev/null; then
  rm "$DESKTOP_TARGET"
  update-desktop-database "${DESKTOP_TARGET%/*}" 2>/dev/null || true
  echo "[6/6] Removed desktop entry (system zellij.desktop is used again)."
fi

echo ""
echo "=== Uninstall complete ==="
