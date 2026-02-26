#!/usr/bin/env bash
set -e

echo "=== Building Zowe MVS Editor ==="
echo "Lazarus: $(lazbuild --version)"
echo "FPC:     $(fpc -iV)"
echo ""

MODE="${1:-Debug}"
echo "Build mode: $MODE"

lazbuild --build-mode="$MODE" editor.lpi

echo ""
echo "=== Build complete: ./editor ==="
