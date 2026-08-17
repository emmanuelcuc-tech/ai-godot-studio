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
StartupNotify=true
Categories=Development;Audio;Game;
EOF
  chmod +x "$path"
  if command -v gio >/dev/null 2>&1; then
    gio set -t string "$path" metadata::trusted true 2>/dev/null || true
    gio set -t string "$path" metadata::xfce-exe-checksum "$(sha256sum "$path" | awk '{print $1}')" 2>/dev/null || true
  fi
  echo "wrote $path"
}

# Saved desktop mixer snapshot (also copied to ~/Desktop).
if [[ -f "$ROOT/saves/audio_studio_1.0.1_desktop.cfg" ]]; then
  cp -f "$ROOT/saves/audio_studio_1.0.1_desktop.cfg" "$DESKTOP/Audio Studio 1.0.1 desktop.cfg"
  echo "wrote $DESKTOP/Audio Studio 1.0.1 desktop.cfg"
fi
cat > "$DESKTOP/Launch Audio Studio.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export DISPLAY="\${DISPLAY:-:1}"
exec "$GODOT" --path "$ROOT" --display-driver x11 res://scenes/audio_studio.tscn
EOF
chmod +x "$DESKTOP/Launch Audio Studio.sh"
echo "wrote $DESKTOP/Launch Audio Studio.sh"

write_desktop "AI Godot Studio" \
  "AI Godot Studio 2.0 — Create tab + Audio Studio mixer" \
  "env DISPLAY=${DISPLAY:-:1} $GODOT --path $ROOT --display-driver x11"

write_desktop "Audio Studio" \
  "Desktop Audio Studio 1.0.1 desktop — 12s slow neon blend" \
  "env DISPLAY=${DISPLAY:-:1} $GODOT --path $ROOT --display-driver x11 res://scenes/audio_studio.tscn"

write_desktop "Audio Studio 1.0.1 desktop" \
  "Saved desktop Audio Studio 1.0.1 — 12s gradual neon blend" \
  "env DISPLAY=${DISPLAY:-:1} $GODOT --path $ROOT --display-driver x11 res://scenes/audio_studio.tscn"

if [[ -d "$ROOT/codea/dist/ChromeCannonGlass.codea" ]]; then
  write_desktop "Chrome Cannon Glass" \
    "Chrome Cannon Glass 1.0.0 final — Codea package" \
    "xdg-open $ROOT/codea/dist/ChromeCannonGlass.codea"
fi
