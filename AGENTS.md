# AI Godot Studio

A **Godot 4.7** desktop application (GDScript) that turns a text description into a
playable Godot 4 project (offline templates by default; optional AI + web search when
API keys are provided). See `README.md` for the product overview and button reference.

## Cursor Cloud specific instructions

### What this is / how to run
- This repo IS a Godot project (`project.godot`, main scene `res://scenes/main.tscn`).
  There is no npm/pip/build step — the "app" is run directly by the Godot engine.
- The `godot` binary (Godot **4.7.1** stable, Linux headless build) is installed at
  `/usr/local/bin/godot` by the environment update script.
- Run the studio GUI: `DISPLAY=:1 godot --path /workspace`
  - A software OpenGL (llvmpipe) + dummy-audio fallback is expected on this VM. The
    `Required Vulkan instance extension` error and the `ALSA ... dummy driver` warnings
    are harmless — the app still renders and works.
  - Launch it under a persistent shell (e.g. tmux) since it is a long-running GUI process.
- Headless smoke test (fast, no display needed, exercises the generators/writer/C++ scaffold):
  `godot --headless --path /workspace --script res://scripts/smoke_test.gd`

### App behavior notes (non-obvious)
- The studio runs **fully offline**: with no API keys it uses `scripts/offline_templates.gd`
  to generate a playable project, so no secrets are required to Create + Run a game.
- Settings (incl. the Godot executable path used by **Run Game**/**Open in Godot**) are stored
  in `user://settings.cfg`, which on Linux is
  `~/.local/share/godot/app_userdata/AI Godot Studio/settings.cfg`.
  The app's auto-detection of the Godot exe only checks Windows paths, so on this VM the
  path must be set to `/usr/local/bin/godot` (either in the Settings tab or by pre-seeding
  that config file). This is required for **Run Game** to launch generated projects.
- **Create Game** writes generated projects into `generated_games/<name>/` (git-ignored).
- **Run Game** launches the generated project as a *separate* Godot process
  (`godot --path <generated_project>`), i.e. a second window.
- API keys can also be supplied via env vars: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
  `GEMINI_API_KEY`, `TAVILY_API_KEY` (see `scripts/app_settings.gd`). These are optional.
- Optional native C++/GDExtension build (`build_cpp.ps1`, SCons) needs `pip install scons`
  + a C/C++ toolchain and clones godot-cpp; not required to run games (GDScript fallback).

### Lint / test / build
- There is no separate linter; Godot reports GDScript parse errors on load. A quick check:
  `godot --headless --path /workspace --quit` (imports + parses the project).
- The `smoke_test.gd` script above is the closest thing to an automated test.
