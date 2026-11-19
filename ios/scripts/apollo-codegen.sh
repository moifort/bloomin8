#!/usr/bin/env bash
# Regenerates the Apollo iOS types (ios/Canvas/CanvasGraphQL/Sources) from
# shared/schema.graphql and the .graphql operations of the app and widget.
#
# Downloads apollo-ios-cli into ios/.tools/ on first use (gitignored), pinned
# to the Apollo iOS version of the app and checked against a known SHA-256.
set -euo pipefail

APOLLO_VERSION="1.18.0"
# GitHub publishes no digest for this release: hash of the archive downloaded
# on 2026-11-19. A mismatch means the asset changed, never run it then.
ARCHIVE_SHA256="afa918ebe588a890cec75b851061aae61edbd99ab9817eec97dd77ba76a919ca"

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$IOS_DIR/.tools/apollo-ios-cli-$APOLLO_VERSION"
CLI="$TOOLS_DIR/apollo-ios-cli"

if [[ ! -x "$CLI" ]]; then
  echo "Downloading apollo-ios-cli $APOLLO_VERSION…"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/apollo-ios-cli.tar.gz" \
    "https://github.com/apollographql/apollo-ios/releases/download/$APOLLO_VERSION/apollo-ios-cli.tar.gz"
  echo "$ARCHIVE_SHA256  $tmp/apollo-ios-cli.tar.gz" | shasum -a 256 -c - >/dev/null || {
    echo "Checksum mismatch for apollo-ios-cli $APOLLO_VERSION, aborting." >&2
    exit 1
  }
  mkdir -p "$TOOLS_DIR"
  tar -xzf "$tmp/apollo-ios-cli.tar.gz" -C "$TOOLS_DIR" apollo-ios-cli
  chmod +x "$CLI"
fi

cd "$IOS_DIR"
"$CLI" generate --path apollo-codegen-config.json
