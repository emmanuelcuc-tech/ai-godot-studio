# AI Godot Studio

Describe a game → **Create Game** builds a playable **Godot 4** project using templates, internet search, AI coding, and matching **CC0 textures, sprites, open addons, and sample projects**.

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

Type new directions and press **Create Game** again to **modify** the same game (updates C++ sources and GDScript). Uncheck **Create with C++** in the Create tab or Settings for GDScript-only.

## Pipeline (ChatGPT-driven)

1. Detect genre from your directions  
2. Load a **Godot 4** starter template and write a playable project immediately (**Run Game** works now)  
3. Overlay **C++ GDExtension** scaffolding (`src/`, `SConstruct`, `bin/game.gdextension`, `build_cpp.ps1`) unless C++ is turned off  
4. Search the web for Godot / GDExtension tutorials / AssetLib / CC0 kits  
5. **ChatGPT plan** — instructions, gameplay, C++ classes, several textures/sprites → `docs/AI_PLAN.md`  
6. Download matching **CC0 textures & sprites** into `assets/` (wall, floor, sky, enemy/player sprites, …)  
7. Search **Godot Asset Library**; record hits in `docs/PLUGINS.md`; unpack a small MIT/CC0 addon zip into `addons/` when it looks like a real plugin  
8. Fetch a small **open Godot 4 sample** (README + key scripts) into `refs/<name>/`  
9. **ChatGPT code** — writes/merges C++ + GDScript using those asset/ref paths  
10. Extra `download_queries` from the AI pull more textures in the background  

Downloads are parallel / time-capped so play is not blocked. Modify mode: type new directions → Create again → plan + assets + code merge into the same project (including `src/*.cpp`).

### Where files land (generated game)

| Path | What |
|------|------|
| `assets/*.png` | CC0 / Wikimedia / procedural textures & sprites |
| `addons/` | Optional open Godot addon (only if zip contains `plugin.cfg` or `addons/`) |
| `refs/<name>/` | Open MIT/CC0 sample README + scripts for the AI to study |
| `docs/RESOURCES.md` | Inventory + licenses of downloaded art / refs / Kenney links |
| `docs/PLUGINS.md` | AssetLib search results + any installed addon |

**Not auto-installed:** Kenney all-in-one packs (linked only — grab from [kenney.nl](https://kenney.nl/assets)), GPL AssetLib plugins, full demo zips over ~8 MB, commercial ROMs/WADs/ripped art.

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

## Run the studio

```powershell
& "C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\kortn\Projects\ai-godot-studio"
```

Output games: `generated_games/`

## Legal

Spiritual recreations / style matches only — original or CC0 art. No commercial ROMs, WADs, or ripped game assets.
