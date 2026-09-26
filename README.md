# Upgraded Journey

Godot 4.7 project (root) + AI asset pipeline (`asset-pipeline/`, see its README).

## Godot MCP (Claude Code drives the editor)

`addons/godot_ai` + `addons/godot_omni` are [Godot-MCP v5.0.39](https://github.com/bebabinlarsson-blip/Godot-MCP)
(MIT). `.mcp.json` registers the `godot-ai` server for Claude Code in project scope; Claude Code asks once to
approve it on the next session start.

Order matters on this machine: start Claude Code (it spawns the server), then open the project in Godot:

```bash
"C:/Users/ozark/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --editor --path .
```

The plugin attaches to the running server and the **Godot MCP** dock turns green. If Godot is opened first, the
plugin tries to spawn its own server, which fails the process-identity check on Windows; just restart Claude Code
or press the dock's reconnect button.

Notes:
- Server HTTP port is **8765** (Docker owns 8000). Set in `.mcp.json` and in Godot Editor Settings `godot_ai/http_port`.
- Telemetry is off (`GODOT_AI_DISABLE_TELEMETRY=1` in `.mcp.json`, `godot_ai/telemetry_enabled=false`).
- `godot_ai/auto_configure_clients=false` so the addon never rewrites `~/.claude.json` behind your back.
- Requires `uv` (`pip install uv`). The first launch downloads the pinned wheel + deps.
