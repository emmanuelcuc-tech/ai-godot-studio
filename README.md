# AI Godot Studio

Describe a game → **Create Game** builds a playable **Godot 4** project using templates, internet search, AI coding, and CC0 texture downloads.

## Buttons

| Button | Action |
|--------|--------|
| **Create Game** | Starts the full pipeline (template + search + AI scripts + assets) |
| **Run Game** | Plays the project with your Godot executable |
| **New Game** | Clears the session and previous directions |
| **Save Game** | Copies the project to a dated folder under `generated_games/` |
| **Open in Godot** | Opens the project in the editor |
| **Show folder** | Reveals files on disk |

Type new directions and press **Create Game** again to **modify** the same game (replaces the brief and updates scripts).

## Pipeline (ChatGPT-driven)

1. Detect genre from your directions  
2. Load a **Godot 4** starter template and write a playable project immediately  
3. Search the web for Godot tutorials / AssetLib / CC0 kits  
4. **ChatGPT plan** — instructions, gameplay, required textures/sprites/addons → `docs/AI_PLAN.md`  
5. Download matching CC0 textures into `assets/`  
6. **ChatGPT code** — writes/merges GDScript scenes to match your directions + plan  
7. Extra `download_queries` from the AI pull more textures  

Modify mode: type new directions → Create again → plan + code merge into the same project.

## Settings

- OpenAI / Claude / Gemini API keys  
- Godot 4 executable path (required for Run)  
- Optional web search (DuckDuckGo / Tavily)  

## Run the studio

```powershell
& "C:\Users\kortn\Downloads\Godot_v4.7.1-stable_win64.exe" --path "C:\Users\kortn\Projects\ai-godot-studio"
```

Output games: `generated_games/`

## Legal

Spiritual recreations / style matches only — original or CC0 art. No commercial ROMs, WADs, or ripped game assets.
