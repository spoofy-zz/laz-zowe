# Zowe MVS Editor

A lightweight text editor built with **Lazarus / Free Pascal** for **Linux** (GTK2), **macOS** (Cocoa), and **Windows** (Win32), with native integration for IBM z/OS (MVS) mainframe systems via the [Zowe CLI](https://docs.zowe.org/stable/user-guide/cli-installcli/).

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
| Choose editor font | Edit → Editor Font… |

### Column ruler and line-length limits

A ruler strip sits between the toolbar and the editor and scrolls in sync with the text:

| Marker | Column | Colour | Purpose |
|---|---|---|---|
| Red / salmon tick | **80** | red | Coding-convention guide (JCL/COBOL) |
| Blue tick | **123** | blue | Hard window limit |

A red vertical guide line is also drawn inside the editor at column 80 (`RightEdge`).

The editor window width is constrained so it cannot be stretched beyond 123 characters wide; the constraint updates automatically when the font is changed.

### Editor font

**Edit → Editor Font…** opens the system font chooser filtered to fixed-pitch (monospace) fonts.  The selected font name and size are saved to `~/.config/laz-zowe/config.ini` and restored on the next launch.

Default font: **Monospace 11** (maps to DejaVu Sans Mono / Liberation Mono on Linux, Menlo on macOS).

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

#### Dataset browser

All three download/upload actions share the same two-step dataset browser instead of a plain text prompt:

1. **HLQ prompt** — enter a high-level qualifier (e.g. `SYS1`) or a full dataset name (e.g. `RVEZ001.JCL`).
2. **Dataset list dialog** — the editor queries `HLQ.*`, `HLQ.*.*`, and `HLQ.*.*.*` in sequence and merges the results into a single scrollable list.  Select a dataset and click **OK**, or double-click to confirm immediately.
   - **Members... button** — select a PDS in the list (or type its name) and click **Members...** to fetch and display all its members.  Pick one and the target field is filled as `DSN(MEMBER)`.
   - **New Member... button** (in the member list dialog) — type a new 1–8 character member name; the editor will create it on MVS when the upload writes to `DSN(NEWMEMBER)`.
   - The **Dataset:** text field is always editable, so you can type or adjust the name (e.g. append `(MEMBER)`) before confirming.
3. **Fallback** — if no datasets are found and the input contained a dot, the member list of that PDS is tried automatically.  If still nothing is found, a plain input box is shown.

#### Upload workflows

**Upload editor content** (`Zowe > Upload Editor Content to MVS...`)
Opens the dataset browser and uploads whatever is currently open in the editor.

**Upload local file** (`Zowe > Upload Local File to MVS...`)
Opens a file-selector dialog to pick any local file, then the dataset browser for the MVS target, then a **transfer mode** choice:

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
| Linux (GTK2) | Ubuntu 24.04 / x86-64 |
| macOS (Cocoa) | macOS 15 Sequoia, Apple Silicon |
| Windows (Win32) | Windows 11 / x86-64 |

---

## Build

### Linux / macOS

```bash
# Debug build (default)
bash build.sh

# Optimised release build
bash build.sh Release
```

**Linux:** run the resulting `./editor` binary directly.

**macOS:** `build.sh` also copies the binary into `editor.app/Contents/MacOS/`.  Launch via `open editor.app` so the menu bar and keyboard focus work correctly.

> **macOS note:** Running `./editor` directly from the terminal also works — the app activates itself via `NSApp.activateIgnoringOtherApps` at startup.

> **macOS icon note:** If you build from the Lazarus IDE (F9), `lazbuild` will wipe the bundle icon. Always use `./build.sh` as the final build step — or after an IDE build, run `./build.sh` once more to restore the icon.

### Windows

```bat
rem Debug build (default)
build.bat

rem Optimised release build
build.bat Release
```

`build.bat` calls `lazbuild` and produces `editor.exe` in the project root.  Run it directly from a Command Prompt or by double-clicking.

> **Windows prerequisite:** Make sure `lazbuild.exe` and `fpc.exe` are on your `PATH` (the Lazarus installer adds them automatically if you tick the option during setup).

---

## Zowe CLI setup

```bash
# Install Zowe CLI (requires Node.js / npm)
npm install -g @zowe/cli

# Create a z/OSMF profile
zowe config init

# Verify the connection
zowe zosmf check status
```

**Linux / macOS:** the editor calls `zowe` through the user's login shell (`$SHELL -ilc`) so that nvm/fnm and Homebrew paths are available regardless of how the app is launched.

**Windows:** `npm install -g @zowe/cli` installs `zowe` as a `.cmd` batch wrapper (`zowe.cmd`).  The editor routes all Zowe calls through `cmd.exe /c` (using the `COMSPEC` environment variable for the absolute path) so that `.cmd` files on `PATH` are resolved correctly.

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
├── uDsBrowse.pas           # Dataset + PDS member browser dialogs (code-only, no LFM)
├── uSynHighlighter.pas     # Custom TSynJCLHighlighter + TSynCOBOLHighlighter
├── uConfig.pas             # Config load/save (IniFiles → ~/.config/laz-zowe/config.ini)
├── uProfileForm.pas        # Zowe profile selection dialog
├── uProfileForm.lfm        # Full widget tree for the profile dialog
├── build.sh                # Build helper for Linux/macOS + .app bundle setup
├── build.bat               # Build helper for Windows
├── editor.app/             # macOS application bundle
└── TESTS/
    └── TEST                # Sample JCL / COBOL job for testing
```

---

## Notes

- **Form designer**: open `editor.lpi` in the Lazarus IDE. Both forms are fully editable in the visual designer — all components are visible and can be moved, resized, or supplemented without modifying `.pas` code.
- **Zowe CLI v3** wraps all `--response-format-json` responses in an envelope `{"success":…,"data":…}`. The `ZoweUnwrapData()` helper in `uZoweOps.pas` handles this transparently. Shell startup noise (e.g. `bash: no job control`) is automatically stripped before JSON parsing.
- **PATH (Linux/macOS)**: Zowe commands are run via `$SHELL -ilc 'zowe ...'` so that nvm/fnm and Homebrew-installed `node`/`zowe` binaries are on the PATH regardless of how the app is launched.
- **PATH (Windows)**: Zowe commands are routed through `cmd.exe /c` (resolved via `COMSPEC`) because npm installs `zowe` as `zowe.cmd`, which `TProcess`/`CreateProcess` cannot locate directly without a shell. Arguments containing spaces are double-quoted automatically.
- **Font**: the editor uses a monospace font (default: `Monospace` on Linux, `Menlo` on macOS, `Courier New` on Windows). Change it via **Edit → Editor Font…**; the choice is persisted in the config file.
- **Config file location**: `~/.config/laz-zowe/config.ini` on Linux/macOS; `%USERPROFILE%\.config\laz-zowe\config.ini` on Windows.
- **Zowe config location**: `~/.zowe/zowe.config.json` on Linux/macOS; `%USERPROFILE%\.zowe\zowe.config.json` on Windows.
- The editor blocks the UI during Zowe operations. Progress is shown in the status bar. Threading can be added later if needed.
- All temp files created during download/upload/submit are written to the system temp directory (`$TMPDIR` on Linux/macOS, `%TEMP%` on Windows) and deleted automatically after use.

---

## License

MIT
