#!/usr/bin/env bash
set -euo pipefail

GUT_VERSION="${GUT_VERSION:-9.5.0}"
ADDONS_DIR="addons"

if [ -d "$ADDONS_DIR/gut" ]; then
  echo "GUT already installed at $ADDONS_DIR/gut"
  exit 0
fi

echo "Downloading GUT v${GUT_VERSION}..."
mkdir -p "$ADDONS_DIR"

ARCHIVE_URL="https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.tar.gz"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

wget -q "$ARCHIVE_URL" -O "$TMPDIR/gut.tar.gz"
tar -xzf "$TMPDIR/gut.tar.gz" -C "$TMPDIR"
cp -r "$TMPDIR/Gut-${GUT_VERSION}/addons/gut" "$ADDONS_DIR/gut"

echo "GUT v${GUT_VERSION} installed to $ADDONS_DIR/gut"
