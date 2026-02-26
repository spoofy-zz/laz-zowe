# Zowe MVS Editor

A lightweight text editor built with **Lazarus / Free Pascal** for Linux, with native integration for IBM z/OS (MVS) mainframe systems via the [Zowe CLI](https://docs.zowe.org/stable/user-guide/cli-installcli/).

---

## Features

### Standard editor
| Action | Shortcut |
|---|---|
| New file | Ctrl+N |
| Open file | Ctrl+O |
| Save | Ctrl+S |
| Save As | Ctrl+Shift+S |
| Cut / Copy / Paste / Select All | Ctrl+X/C/V/A |

### Zowe / MVS integration
| Action | Shortcut |
|---|---|
| Download dataset from MVS | Zowe menu |
| Upload dataset to MVS | Zowe menu |
| Submit current content as JCL job | F5 |
| View job list and spool output | F6 |
| Check Zowe connection | Zowe menu |

A toolbar with colour-coded icons provides one-click access to all actions.
Hovering a button shows a tooltip with the action name and keyboard shortcut.

---

## Requirements

| Tool | Tested version |
|---|---|
| [Lazarus IDE](https://www.lazarus-ide.org/) / `lazbuild` | 4.2 |
| Free Pascal Compiler (`fpc`) | 3.2.2 |
| [Zowe CLI](https://docs.zowe.org/stable/user-guide/cli-installcli/) | 8.x (v3 release) |
| Linux (GTK2) | Ubuntu 22.04 / 24.04 |

---

## Build

```bash
# Debug build (default)
bash build.sh

# Optimised release build
bash build.sh Release
```

The compiled binary is written to `./editor`.

---

## Zowe CLI setup

The editor calls `zowe` directly; your Zowe profile must be configured before use.

```bash
# Install Zowe CLI (requires Node.js / npm)
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
├── editor.lpr          # Lazarus project entry point
├── editor.lpi          # lazbuild project configuration
├── uMain.pas           # Main editor form (programmatic LCL UI)
├── uZoweOps.pas        # Zowe CLI wrapper (TProcess, pipe-polling)
├── uJobsForm.pas       # Jobs & spool viewer form
├── build.sh            # Build helper script
└── TESTS/
    └── TEST            # Sample JCL / COBOL job for testing
```

---

## Notes

- **Zowe CLI v3** wraps all `--response-format-json` responses in an envelope
  `{"success":…,"data":…}`. The `ZoweUnwrapData()` helper in `uZoweOps.pas`
  handles this transparently.
- The editor blocks the UI during Zowe operations. Progress is shown in the
  status bar. Threading can be added later if needed.
- All temp files created during download/upload/submit are written to
  `$TMPDIR` and deleted automatically after use.

---

## License

MIT
