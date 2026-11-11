#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMED_DIR="$HOME/.config/omarchy/themed"
HOOKS_DIR="$HOME/.config/omarchy/hooks"
ZELLIJ_CONFIG="$HOME/.config/zellij/config.kdl"
OLD_THEME_FILE="$HOME/.config/zellij/themes/omarchy.kdl"
BIN_DIR="$HOME/.local/bin"
LAUNCHER_TARGET="$BIN_DIR/zellij-launcher"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_TARGET="$APPS_DIR/zellij.desktop"
SESSION_START_MARKER="# --- omarchy-zellij-theme session (start) ---"
SESSION_END_MARKER="# --- omarchy-zellij-theme session (end) ---"

echo "=== omarchy-zellij-theme installer ==="

# Strip our managed alias block from a shell rc file.
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

# Make bare `zellij` in interactive shells use the fixed session.
install_session_alias() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0
  remove_session_alias "$rc"
  if [[ -s "$rc" && -n "$(tail -c 1 "$rc")" ]]; then
    echo >> "$rc"
  fi
  {
    echo "$SESSION_START_MARKER"
    echo "alias zellij='$LAUNCHER_TARGET'"
    echo "$SESSION_END_MARKER"
  } >> "$rc"
}

# 1. Symlink template
mkdir -p "$THEMED_DIR"
if [[ -L "$THEMED_DIR/zellij.kdl.tpl" ]]; then
  echo "[1/6] Template symlink already exists, updating..."
  rm "$THEMED_DIR/zellij.kdl.tpl"
fi
ln -s "$SCRIPT_DIR/zellij.kdl.tpl" "$THEMED_DIR/zellij.kdl.tpl"
echo "[1/6] Symlinked template -> $THEMED_DIR/zellij.kdl.tpl"

# 2. Install hook
mkdir -p "$HOOKS_DIR/theme-set.d"

# Migrate legacy single-file hook (pre-Omarchy 4) if present
if [[ -f "$HOOKS_DIR/theme-set" ]] && grep -q "omarchy-zellij" "$HOOKS_DIR/theme-set" 2>/dev/null; then
  echo "[2/6] Migrating legacy theme-set hook to theme-set.d/..."
  if [[ -L "$HOOKS_DIR/theme-set" ]]; then
    rm "$HOOKS_DIR/theme-set"
  else
    sed -i '/# --- omarchy-zellij-theme integration (start) ---/,/# --- omarchy-zellij-theme integration (end) ---/d' "$HOOKS_DIR/theme-set"
  fi
fi

HOOK_TARGET="$HOOKS_DIR/theme-set.d/omarchy-zellij-theme"
if [[ -L "$HOOK_TARGET" || -f "$HOOK_TARGET" ]]; then
  rm "$HOOK_TARGET"
fi
ln -s "$SCRIPT_DIR/theme-set" "$HOOK_TARGET"
echo "[2/6] Installed hook -> $HOOK_TARGET"

# 3. Configure Zellij to use the "omarchy" theme
if [[ -f "$ZELLIJ_CONFIG" ]]; then
  # Zellij 0.45 can also choose themes with theme_dark/theme_light. When both
  # are active they override the static theme, so nothing may compete with ours.
  if grep -q '^theme "omarchy"' "$ZELLIJ_CONFIG" 2>/dev/null &&
    ! grep -qE '^theme_(dark|light)[[:space:]]' "$ZELLIJ_CONFIG" 2>/dev/null; then
    echo "[3/6] Zellij config already has theme \"omarchy\", skipping."
  else
    cp "$ZELLIJ_CONFIG" "$ZELLIJ_CONFIG.bak.$(date +%s)"
    sed -i -E 's#^([[:space:]]*)(theme|theme_dark|theme_light)([[:space:]]+")#\1// \2\3#' "$ZELLIJ_CONFIG"
    if grep -q '^// *theme ' "$ZELLIJ_CONFIG" 2>/dev/null; then
      sed -i '0,/^\/\/ *theme /{s|^// *theme .*|theme "omarchy"|}' "$ZELLIJ_CONFIG"
    else
      echo '' >> "$ZELLIJ_CONFIG"
      echo 'theme "omarchy"' >> "$ZELLIJ_CONFIG"
    fi
    echo "[3/6] Set theme \"omarchy\" in Zellij config (backup created)."
  fi
else
  echo "[3/6] WARNING: Zellij config not found at $ZELLIJ_CONFIG"
fi

# 4. Clean up old theme file from previous approach
if [[ -f "$OLD_THEME_FILE" ]]; then
  rm "$OLD_THEME_FILE"
  echo "[4/6] Removed old theme file from previous approach ($OLD_THEME_FILE)."
else
  echo "[4/6] No old theme file to clean up."
fi

# 5. Install launcher for the fixed "alila" session
mkdir -p "$BIN_DIR"
if [[ -L "$LAUNCHER_TARGET" || -f "$LAUNCHER_TARGET" ]]; then
  rm "$LAUNCHER_TARGET"
fi
chmod +x "$SCRIPT_DIR/zellij-launcher"
ln -s "$SCRIPT_DIR/zellij-launcher" "$LAUNCHER_TARGET"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  install_session_alias "$rc"
done

# GUI launches (Omarchy menu, app launcher) never read shell aliases, so point
# the desktop entry at the launcher as well.
mkdir -p "$APPS_DIR"
cat > "$DESKTOP_TARGET" <<EOF
[Desktop Entry]
Version=1.0
Name=Zellij
Type=Application
Comment=Manage Your Terminal Applications
Terminal=true
Exec="$LAUNCHER_TARGET"
Icon=zellij
Categories=ConsoleOnly;System;
GenericName=Terminal Multiplexer
EOF
update-desktop-database "$APPS_DIR" 2>/dev/null || true

echo "[5/6] Installed zellij launcher (default session \"alila\") -> $LAUNCHER_TARGET"
echo "[5/6] Installed desktop entry -> $DESKTOP_TARGET"

# 6. Generate and inject theme into config.kdl
CURRENT_THEME=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo "")
if [[ -n "$CURRENT_THEME" ]]; then
  echo "[6/6] Applying current theme '$CURRENT_THEME' to Zellij..."
  omarchy theme refresh
  echo "[6/6] Done! Theme injected inline into config.kdl (hot-reload enabled)."
else
  echo "[6/6] No current theme found. Theme will sync on next omarchy theme set."
fi

echo ""
echo "=== Installation complete ==="
echo "To revert, run: $SCRIPT_DIR/uninstall.sh"
