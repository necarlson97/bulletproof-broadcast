# Godot CLI (this machine / Steam)

**Editor executable (tools build):**

`F:\Program Files (x86)\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`

**Version:** 4.6.2.stable (Steam build; run `--version` to confirm).

## PowerShell

Path has spaces — always invoke with the call operator `&`:

```powershell
& "F:\Program Files (x86)\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --version
```

## Project path

This repo’s `project.godot` lives at:

`f:\godot\bulletproof-broadcast`

## Useful flags

- `--path <dir>` — use that folder as the project root (must contain `project.godot`).
- `--headless` — no window (good for scripted checks).
- `--quit` — exit after startup (often paired with `--headless` or editor automation).
- `--editor` — open the editor for the given project.

Example (open project in editor, then exit — adjust to your workflow):

```powershell
& "F:\Program Files (x86)\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path "f:\godot\bulletproof-broadcast" --headless --quit
```

**Export templates** (for reference) are under the install dir, e.g.:

`...\Godot Engine\editor_data\export_templates\4.6.2.stable\`
