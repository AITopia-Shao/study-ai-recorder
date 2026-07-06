#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.3.9}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINDOWS_DIR="$ROOT_DIR/windows"
RELEASE_DIR="$ROOT_DIR/dist/release"

mkdir -p "$RELEASE_DIR"

cd "$WINDOWS_DIR"
npm install
npm run dist -- --config.extraMetadata.version="$VERSION"

ARTIFACT="$WINDOWS_DIR/dist/Trace-v${VERSION}-Windows-x64-Setup.exe"
TARGET="$RELEASE_DIR/Trace-v${VERSION}-Windows-x64-Setup.exe"

if [[ ! -f "$ARTIFACT" ]]; then
  echo "Windows artifact not found: $ARTIFACT" >&2
  exit 1
fi

cp "$ARTIFACT" "$TARGET"
shasum -a 256 "$TARGET" | sed "s#  $RELEASE_DIR/#  #" > "$TARGET.sha256"

echo "$TARGET"
echo "$TARGET.sha256"
