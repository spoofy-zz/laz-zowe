#!/usr/bin/env bash
set -e

echo "=== Building Zowe MVS Editor ==="
echo "Lazarus: $(lazbuild --version)"
echo "FPC:     $(fpc -iV)"
echo ""

MODE="${1:-Debug}"
echo "Build mode: $MODE"

lazbuild --build-mode="$MODE" editor.lpi

# On macOS, put the binary inside the .app bundle so the window server
# activates it properly (menu bar + keyboard focus).
if [[ "$(uname)" == "Darwin" ]]; then
  # Regenerate the bundle icon (only if make_icon.py changed or icns is missing)
  ICNS="editor.app/Contents/Resources/AppIcon.icns"
  if [[ ! -f "$ICNS" ]] || [[ make_icon.py -nt "$ICNS" ]]; then
    echo "=== Generating icon ==="
    python3 make_icon.py
  fi

  mkdir -p editor.app/Contents/MacOS
  # Use a symlink so the bundle always references the freshly built binary
  # without needing a copy. Remove any stale file/symlink first.
  TARGET="editor.app/Contents/MacOS/editor"
  if [[ ! -L "$TARGET" ]] || [[ "$(readlink "$TARGET")" != "../../../editor" ]]; then
    ln -sf "../../../editor" "$TARGET"
    echo "=== Linked binary into editor.app/Contents/MacOS/ ==="
  fi
  echo "=== Build complete ==="
  echo "=== Run with:  open editor.app  ==="
else
  echo "=== Build complete: ./editor ==="
fi
