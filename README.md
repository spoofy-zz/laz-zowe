# Zowe MVS Editor

A lightweight text editor built with **Lazarus / Free Pascal** for **macOS** (Cocoa), with native integration for IBM z/OS (MVS) mainframe systems via the [Zowe CLI](https://docs.zowe.org/stable/user-guide/cli-installcli/).

The editor is **Lazarus form-designer friendly**: all UI components are declared as published fields and the `.lfm` files contain the full widget tree, so you can open the project in the Lazarus IDE and visually modify the layout without touching any code.

---

## Features

### Standard editor

| Action | Shortcut |
|---|---|
| New file | Ctrl+N |
| Open file | Ctrl+O |
| Save | Ctrl+S |
| Save As | Ctrl+Shift+S |
| Clear editor (new empty document) | File menu / toolbar |
| Cut / Copy / Paste / Select All | Ctrl+X/C/V/A |

### Syntax highlighting

The editor uses **SynEdit** and automatically detects the file type from the extension, dataset name, or content:

| Language | Detection | Colours |
|---|---|---|
| **IBM MVS JCL** | `.jcl`, `.proc`; dataset name contains `.JCL`/`.PROC`; first line starts with `//` | `//` prefix white·bold, job/step name cyan, keywords (`JOB` `EXEC` `DD`) yellow·bold, parameters orange, strings magenta, comments green·italic |
| **COBOL** | `.cbl`, `.cob`, `.cpy`; dataset name contains `.CBL`/`.COB`; line contains `IDENTIFICATION DIVISION` | Division/section headers bold, reserved words yellow·bold, level numbers bold, `PIC`/`OCCURS` soft-green, strings magenta, comments (col 7 `*`) green·italic |

The current syntax type is shown in the right panel of the status bar (`Syntax: JCL`, `Syntax: COBOL`, or `Syntax: –`).

### Zowe / MVS integration

| Action | Shortcut |
|---|---|
| Download dataset from MVS | Zowe menu |
| Upload editor content to MVS | Zowe menu |
| Upload local file to MVS (without opening it) | Zowe menu |
| Submit current content as JCL job | F5 |
| View job list and spool output | F6 |
| Check Zowe connection | Zowe menu |
| Configure Zowe profile | Zowe menu |

#### Upload workflows

**Upload editor content** (`Zowe > Upload Editor Content to MVS...`)
Opens a dataset-name prompt and uploads whatever is currently open in the editor.

**Upload local file** (`Zowe > Upload Local File to MVS...`)
Opens a file-selector dialog to pick any local file, then a dataset-name prompt for the MVS target, then a **transfer mode** choice:

| Mode | Zowe flag | When to use |
|---|---|---|
| Text | *(default)* | JCL, COBOL, scripts — converts line endings |
| Binary | `--binary` | Load modules, ZIPs, images — byte-for-byte copy |

The file is transferred directly — it is never opened in the editor.

Both upload actions share a **last-used dataset name**: the dataset entered in either dialog is remembered and pre-filled the next time either action is invoked.

#### Zowe profile configuration

`Zowe > Configure Profile...` opens a dialog that lets you choose between the **default Zowe profile** and a **named profile** from your `zowe.config.json`.

- The available profiles are read directly from `~/.zowe/zowe.config.json` and shown in a list; click one to select it, or type a name by hand.
- The setting is saved locally to `~/.config/laz-zowe/config.ini` and restored on the next launch.
- The active profile is shown in the right-hand panel of the status bar (`Profile: default` or `Profile: myprofile`).
- When a named profile is active, every Zowe command is issued with `--zosmf-profile <name>`, so multiple z/OS hosts can be targeted without changing the global default.

#### Jobs & spool viewer (`F6`)

Opens a two-pane window: job list on the left, spool content on the right.

| Feature | How |
|---|---|
| Refresh job list | "Refresh Jobs" button; filter by owner with the Owner field |
| Sort order | Jobs are always sorted ascending by Job ID |
| Load spool file list | Click a job — the spool-file selector populates automatically |
| View spool | Select a spool file (or "All spool") and click "View Spool" |
| View spool quickly | Double-click a job — opens all-spool content immediately |
| Delete a job | Select a job, click "Delete Job" or press **Delete**; a confirmation dialog is shown before `zowe zos-jobs delete job` is called; the list refreshes automatically on success |

A toolbar with colour-coded icons provides one-click access to all actions.
Hovering a button shows a tooltip with the action name and keyboard shortcut.

---

## Requirements

| Tool | Tested version |
|---|---|
| [Lazarus IDE](https://www.lazarus-ide.org/) / `lazbuild` | 4.2 |
| Free Pascal Compiler (`fpc`) | 3.2.2 |
| [Zowe CLI](https://docs.zowe.org/stable/user-guide/cli-installcli/) | 8.x (v3 release) |
| macOS (Cocoa) | macOS 15 Sequoia, Apple Silicon |

---

## Build

```bash
# Debug build (default) – also wires the binary into editor.app
bash build.sh

# Optimised release build
bash build.sh Release

# Run as a proper .app so the menu bar and keyboard focus work correctly
open editor.app
```

The `build.sh` script calls `lazbuild`, regenerates the `.icns` icon if needed, and copies the binary into `editor.app/Contents/MacOS/` so launching via `open editor.app` activates the macOS menu bar.

> **Note:** Running `./editor` directly from the terminal also works — the app activates itself via `NSApp.activateIgnoringOtherApps` at startup.

---

## Zowe CLI setup

The editor calls `zowe` through the user's login shell (`$SHELL -ilc`) so that nvm/fnm and Homebrew paths are available regardless of how the app is launched.

```bash
# Install Zowe CLI (requires Node.js / npm or nvm)
npm install -g @zowe/cli

# Create a z/OSMF profile
zowe config init

# Verify the connection
zowe zosmf check status
```

Refer to the [Zowe CLI documentation](https://docs.zowe.org/stable/user-guide/cli-installcli/) for full profile configuration.

---

## Project structure

```
.
├── editor.lpr              # Lazarus program entry point (macOS activation)
├── editor.lpi              # lazbuild project config (requires LCL + SynEdit)
├── uMain.pas               # Main editor form – published fields, FormCreate
├── uMain.lfm               # Full widget tree (menu, toolbar, SynEdit, statusbar)
├── uJobsForm.pas           # Jobs & spool viewer form
├── uJobsForm.lfm           # Full widget tree for job viewer
├── uZoweOps.pas            # Zowe CLI wrapper (TProcess, pipe-polling, shell fix, profile flag)
├── uSynHighlighter.pas     # Custom TSynJCLHighlighter + TSynCOBOLHighlighter
├── uConfig.pas             # Config load/save (IniFiles → ~/.config/laz-zowe/config.ini)
├── uProfileForm.pas        # Zowe profile selection dialog
├── uProfileForm.lfm        # Full widget tree for the profile dialog
├── build.sh                # Build helper + .app bundle setup
├── editor.app/             # macOS application bundle
└── TESTS/
    └── TEST                # Sample JCL / COBOL job for testing
```

---

## Notes

- **Form designer**: open `editor.lpi` in the Lazarus IDE. Both forms are fully editable in the visual designer — all components are visible and can be moved, resized, or supplemented without modifying `.pas` code.
- **Zowe CLI v3** wraps all `--response-format-json` responses in an envelope `{"success":…,"data":…}`. The `ZoweUnwrapData()` helper in `uZoweOps.pas` handles this transparently. Shell startup noise (e.g. `bash: no job control`) is automatically stripped before JSON parsing.
- **macOS PATH**: Zowe commands are run via `$SHELL -ilc 'zowe ...'` so that nvm/fnm and Homebrew-installed `node`/`zowe` binaries are on the PATH regardless of how the app is launched.
- The editor blocks the UI during Zowe operations. Progress is shown in the status bar. Threading can be added later if needed.
- All temp files created during download/upload/submit are written to `$TMPDIR` and deleted automatically after use.

---

## License

MIT
