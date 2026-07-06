#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
APP_NAME="Trace"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
PACKAGE_DIR="$ROOT_DIR/dist/release"
ZIP_NAME="Trace-v$VERSION-macOS-arm64.zip"
ZIP_PATH="$PACKAGE_DIR/$ZIP_NAME"
CHECKSUM_PATH="$ZIP_PATH.sha256"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build_app.sh" "$VERSION"

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc "$APP_DIR" "$ZIP_PATH"
(cd "$PACKAGE_DIR" && shasum -a 256 "$ZIP_NAME" > "$(basename "$CHECKSUM_PATH")")

echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"
