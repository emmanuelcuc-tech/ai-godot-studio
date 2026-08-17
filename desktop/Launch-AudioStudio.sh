#!/usr/bin/env bash
# Launch desktop Audio Studio (mixer, IN/OUT, describe / record / hum).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -f "$ROOT/project.godot" ]]; then
  echo "project.godot missing at $ROOT" >&2
  exit 1
fi
GODOT="${GODOT:-}"
if [[ -z "$GODOT" ]]; then
  for c in /usr/local/bin/godot /usr/bin/godot godot; do
    if command -v "$c" >/dev/null 2>&1 || [[ -x "$c" ]]; then
      GODOT="$c"
      break
    fi
  done
fi
if [[ -z "$GODOT" ]]; then
  echo "Godot 4 executable not found." >&2
  exit 1
fi
export DISPLAY="${DISPLAY:-:1}"
exec "$GODOT" --path "$ROOT" --display-driver x11 res://scenes/audio_studio.tscn
