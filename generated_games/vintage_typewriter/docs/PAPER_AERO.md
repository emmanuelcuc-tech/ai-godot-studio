# Paper & feed

## Paper types (Settings)

Selectable via **Paper type** OptionButton (`TwSettings.paper_type` + `HQAssets`):

| Id | Label | Source |
|----|-------|--------|
| `recycled` | Recycled fiber | `assets/images/paper/recycled.jpg` |
| `kraft` | Kraft gray | `assets/images/paper/kraft.jpg` |
| `beige` | Plain beige | `assets/images/paper/beige.jpg` |
| `underwood_desk` | Underwood desk (photo) | `assets/images/paper/underwood_desk.jpg` |
| `white` … `black` | Procedural color tints | baked by `HQAssets` |

## Feed (original GDScript)

`paper_feed.gd` — TypingSimulator has no visual platen; we reimplemented:

- **Return** → one line advance (`advance_line`)
- **FEED ↑/↓ / knobs / arrows** → manual roll
- **Grab & drag** → manual platen pull
- Typing does **not** slide the sheet; `RichTextLabel.scroll_to_line` only

## Sound

Drop-ins in `assets/audio/`: `key.ogg`, `erase.ogg`, `return.ogg`, `bell.ogg`, `feed.ogg`  
(aliases: `key_strike.ogg`, `page_feed.ogg`, `enter_bell.ogg`)

## License note

TypingSimulator-main is MIT (Abdullah Al Ashrafee) — see `assets/TYPING_SIMULATOR_LICENSE.txt`.  
Paper photos/textures are separate drop-ins used as paper **types**, not claimed as that project's assets.
