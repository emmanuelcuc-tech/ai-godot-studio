# AI Godot Studio

Describe a game → **Create Game** builds a playable **Godot 4** project using templates, internet search, AI coding, and **visible art** (textures, sprites, and/or simple models).

**Create defaults to C++ (GDExtension).** Games include `src/` godot-cpp gameplay plus a **GDScript fallback** so **Run Game** works before you compile.

## Buttons

| Button | Action |
|--------|--------|
| **Create Game** | Starts the full pipeline (template + C++ scaffold + search + AI + assets) |
| **Run Game** | Plays the project with your Godot executable (GDScript fallback, or native C++ after build) |
| **New Game** | Clears the session and previous directions |
| **Save Game** | Copies the project to a dated folder under `generated_games/` |
| **Open in Godot** | Opens the project in the editor |
| **Show folder** | Reveals files on disk |

After **Run Game**, type new directions and press **Create Game** / **Update / Edit Game** to **modify the same project**. **New Game** is the only full reset. Uncheck **Create with C++** in the Create tab or Settings for GDScript-only.

On Create, check **Textures**, **Sprites**, and/or **Models**. Every game gets real `assets/` files (CC0 download when possible, generated colored PNGs + a simple character mesh otherwise) so Run Game is never untextured gray. Create also copies matching useful files from **`F:/asset`** (Settings → Local asset folder) into the new game — materials, textures, models, character/player hits, and a GDScript-safe physics helper addon when compatible. Attribution lands in `docs/F_ASSET_ATTRIBUTION.md`. Runtime never links to `F:`.

After Create, open the **Edit Game** tab to **Add more / Change** Character · World · Enemy · Weapon · Materials · Physics from `F:/asset` or the project’s `assets/`. Create keeps a short link: “Open Edit Game to add more from F:\\asset”. **Library** browses the generated project folders only.

## Pipeline (ChatGPT-driven)

1. Detect genre from your directions  
2. Load a **Godot 4** starter template and write a playable project immediately (**Run Game** works now)  
3. Overlay **C++ GDExtension** scaffolding (`src/`, `SConstruct`, `bin/game.gdextension`, `build_cpp.ps1`) unless C++ is turned off  
4. Search the web for Godot / GDExtension tutorials / AssetLib / CC0 kits  
5. **ChatGPT plan** — instructions, gameplay, C++ classes, several textures/sprites → `docs/AI_PLAN.md`  
6. Write **wall / floor / character / enemy art** into `assets/` (Openverse/Wikimedia CC0 when available, generated fallback always)  
6b. Copy matching useful files from local **`F:/asset`** into `assets/` + optional `addons/f_asset_physics/`  
7. Search **Godot Asset Library**; record hits in `docs/PLUGINS.md`; unpack a small MIT/CC0 addon zip into `addons/` when it looks like a real plugin  
8. Fetch a small **open Godot 4 sample** (README + key scripts) into `refs/<name>/`  
9. **ChatGPT code** — writes/merges C++ + GDScript using those asset/ref paths  
10. Extra `download_queries` from the AI pull more textures in the background  

Downloads are parallel / time-capped so play is not blocked. Modify mode: type new directions → Create again → plan + assets + code merge into the same project (including `src/*.cpp`).

### Where files land (generated game)

| Path | What |
|------|------|
| `assets/*.png` + category folders | Wall/floor/sky, character/enemy sprites, generated `character.obj` |
| `addons/` | Optional open Godot addon (only if zip contains `plugin.cfg` or `addons/`) |
| `refs/<name>/` | Open MIT/CC0 sample README + scripts for the AI to study |
| `docs/RESOURCES.md` | Inventory + licenses of downloaded art / refs / Kenney links |
| `docs/PLUGINS.md` | AssetLib search results + any installed addon |
| `docs/F_ASSET_ATTRIBUTION.md` | LICENSE / ATTRIBUTION copied from local `F:/asset` |
| `addons/f_asset_physics/` | Optional GDScript-safe joints/grab from `F:/asset` (C# skipped) |

**Not auto-installed:** Kenney all-in-one packs (linked only — grab from [kenney.nl](https://kenney.nl/assets)), GPL AssetLib plugins, full demo zips over ~8 MB, commercial ROMs/WADs/ripped art. Other `F:\` dumps (Battlefield, zips, ROMs) are never scanned — only `F:/asset`.

## C++ / GDExtension

Each generated game (C++ mode) contains:

- `src/game_player.*`, `src/game_world.*`, `src/game_enemy.*`, `src/game_app.*` — intended native gameplay  
- `bin/game.gdextension` — extension manifest  
- `SConstruct` / `CMakeLists.txt` — godot-cpp style build  
- `scripts/` + `scenes/main.tscn` — playable fallback  
- `scenes/main_cpp.tscn` — native node scene (use after a successful build)  
- `docs/CPP_BUILD.md` — how to compile  

### Build requirements

- Python 3 + `pip install scons`  
- Git (clones [godot-cpp](https://github.com/godotengine/godot-cpp))  
- C++ compiler: **MSVC** (Visual Studio 2022 Build Tools) on Windows, or clang/g++  

```powershell
cd generated_games\<your_game>
.\build_cpp.ps1
```

If a compiler is detected, Create may start this build in the background. First compile takes several minutes. Until the `.dll` / `.so` exists, Run Game uses GDScript; a HUD line reports extension status.

## Settings

- OpenAI / Claude / Gemini API keys  
- Godot 4 executable path (required for Run)  
- **Create with C++ / GDExtension** (default on)  
- Optional web search (DuckDuckGo / Tavily)  
- **Local asset folder** (default `F:/asset` only — never whole `F:` / Battlefield / ROMs)  

## Run the studio

```powershell
& "C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\kortn\Projects\ai-godot-studio"
```

Output games: `generated_games/`

## Legal

Spiritual recreations / style matches only — original or CC0 art. No commercial ROMs, WADs, or ripped game assets.
