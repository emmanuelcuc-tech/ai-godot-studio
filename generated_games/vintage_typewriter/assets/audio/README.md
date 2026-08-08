# Audio (drop-in)

Place new typewriter sounds here. The machine is **silent** until these files exist.

| File | Use |
|------|-----|
| `key.ogg` | Key strike |
| `erase.ogg` | Backspace / erase |
| `return.ogg` | Carriage return (falls back to `feed.ogg` if missing) |
| `bell.ogg` | Margin / return bell |
| `feed.ogg` | Platen / paper feed |

`typewriter_sfx.gd` loads these when present; otherwise plays nothing.
