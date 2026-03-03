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

  # ── Icon ──────────────────────────────────────────────────────────────
  # lazbuild leaves Resources/ empty on every build.
  # Regenerate the .icns if needed, then always copy it into the bundle.
  ROOT_ICNS="AppIcon.icns"
  RES_DIR="editor.app/Contents/Resources"
  if [[ ! -f "$ROOT_ICNS" ]] || [[ make_icon.py -nt "$ROOT_ICNS" ]]; then
    echo "=== Generating icon ==="
    python3 make_icon.py
  fi
  mkdir -p "$RES_DIR"
  cp "$ROOT_ICNS" "$RES_DIR/AppIcon.icns"
  echo "=== Installed icon into $RES_DIR/ ==="

  # ── Binary ────────────────────────────────────────────────────────────
  mkdir -p editor.app/Contents/MacOS
  TARGET="editor.app/Contents/MacOS/editor"
  rm -f "$TARGET"
  cp editor "$TARGET"
  echo "=== Copied binary into editor.app/Contents/MacOS/ ==="

  # ── Info.plist ────────────────────────────────────────────────────────
  # lazbuild regenerates Info.plist on every build without CFBundleIconFile.
  # Patch it unconditionally so the icon always shows in Finder and Dock.
  PLIST="editor.app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$PLIST"
  echo "=== Patched Info.plist with CFBundleIconFile ==="

  # ── LaunchServices cache flush ─────────────────────────────────────────
  # Force Finder and the Dock to re-read the bundle so the icon appears
  # immediately without needing to log out.
  touch editor.app
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/\
LaunchServices.framework/Versions/A/Support/lsregister \
    -f editor.app 2>/dev/null || true
  killall Dock 2>/dev/null || true

  echo "=== Build complete ==="
  echo "=== Run with:  open editor.app  ==="
else
  echo "=== Build complete: ./editor ==="
fi
