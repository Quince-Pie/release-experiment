#!/usr/bin/env bash
# sbom.sh - produce the release SBOM with syft from the built binary.
#
#   sbom.sh ASSET_DIR OUT_FILE
#
# The binary (not the source tree) is scanned so the SBOM records the exact
# Go toolchain/stdlib version linked in, which is what vulnerability matching
# needs. All release targets are built from the same module graph with the
# same toolchain, so one SBOM describes every archive; only the root package
# name/digest would differ per target.
set -euo pipefail

dir="${1:?usage: sbom.sh ASSET_DIR OUT_FILE}"
out="${2:?usage: sbom.sh ASSET_DIR OUT_FILE}"

archive="$(find "$dir" -maxdepth 1 -name '*_linux_amd64.tar.gz' | head -n1)"
[ -n "$archive" ] || {
  echo "sbom: no *_linux_amd64.tar.gz in $dir" >&2
  exit 1
}
version="$(basename "$archive" | sed -E 's/^relver_(.*)_linux_amd64\.tar\.gz$/\1/')"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
tar -xzf "$archive" -C "$tmp" ./relver

syft scan "file:$tmp/relver" \
  --source-name relver --source-version "$version" \
  --output "${SBOM_FORMAT:-spdx-json}=$out" --quiet
echo "sbom: wrote $out (${SBOM_FORMAT:-spdx-json}, relver $version)"
