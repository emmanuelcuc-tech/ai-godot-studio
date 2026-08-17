#!/usr/bin/env bash
# Remake Linux .desktop launchers for this checkout.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESKTOP="${XDG_DESKTOP_DIR:-$HOME/Desktop}"
GODOT="${GODOT:-/usr/local/bin/godot}"
mkdir -p "$DESKTOP"

write_desktop() {
  local name="$1"
  local comment="$2"
  local exec_line="$3"
  local path="$DESKTOP/$name.desktop"
  cat > "$path" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$name
Comment=$comment
Exec=$exec_line
Path=$ROOT
Icon=$ROOT/icon.svg
Terminal=false
Categories=Development;Audio;Game;
EOF
  chmod +x "$path"
  echo "wrote $path"
}

write_desktop "AI Godot Studio" \
  "AI Godot Studio 2.0 — Create tab + Audio Studio mixer" \
  "$GODOT --path $ROOT"

write_desktop "Audio Studio" \
  "Desktop Audio Studio 1.0.0 final — mixer, IN/OUT, describe / record / hum" \
  "$GODOT --path $ROOT res://scenes/audio_studio.tscn"

if [[ -d "$ROOT/codea/dist/ChromeCannonGlass.codea" ]]; then
  write_desktop "Chrome Cannon Glass" \
    "Chrome Cannon Glass 1.0.0 final — Codea package" \
    "xdg-open $ROOT/codea/dist/ChromeCannonGlass.codea"
fi
