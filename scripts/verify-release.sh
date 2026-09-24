#!/usr/bin/env bash
# verify-release.sh - verify a published release exactly as a consumer should.
#
#   verify-release.sh [--repo OWNER/REPO] [--dir DIR] [--rebuild] VERSION
#
#   1. download SHA256SUMS and every archive it lists from the release;
#   2. check the archives against SHA256SUMS;
#   3. fetch the build-provenance and SBOM attestations for every archive
#      from the GitHub attestations API and verify them with cosign against
#      the Sigstore public-good trust root, accepting only certificates issued
#      to THIS repository's release workflow running for THIS tag;
#   4. with --rebuild: rebuild the assets from the tag with Nix and require an
#      identical SHA256SUMS, i.e. an independent reproduction of the release.
#
# Needs curl, jq, sha256sum, snzip, cosign (and nix for --rebuild). No gh CLI.
# GITHUB_TOKEN/GH_TOKEN are optional and only raise the API rate limit.
set -euo pipefail

repo="${GITHUB_REPOSITORY:-Quince-Pie/release-experiment}"
workflow="${RELEASE_WORKFLOW:-release.yml}"
provenance_type="https://slsa.dev/provenance/v1"
sbom_type="${SBOM_PREDICATE_TYPE:-https://spdx.dev/Document/v2.3}"
dir="" rebuild=0 version=""

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}
die() {
  echo "verify-release: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      shift
      repo="${1:-}"
      ;;
    --dir)
      shift
      dir="${1:-}"
      ;;
    --rebuild) rebuild=1 ;;
    -h | --help) usage ;;
    -*) die "unknown option $1" ;;
    *) version="$1" ;;
  esac
  shift
done
[ -n "$version" ] || usage
version="${version#v}"
tag="v$version"
dir="${dir:-$(mktemp -d)}"
mkdir -p "$dir"

api="${GITHUB_API_URL:-https://api.github.com}"
server="${GITHUB_SERVER_URL:-https://github.com}"
base="$server/$repo/releases/download/$tag"
issuer="https://token.actions.githubusercontent.com"
identity="$server/$repo/.github/workflows/$workflow@refs/tags/$tag"
auth=()
if [ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]; then
  auth=(-H "Authorization: Bearer ${GITHUB_TOKEN:-$GH_TOKEN}")
fi

fetch() { # URL OUT
  curl -fsSL --retry 6 --retry-delay 5 --retry-all-errors -o "$2" "$1" ||
    die "download failed: $1"
}

echo "verify-release: $repo $tag -> $dir"

# 1. download
fetch "$base/SHA256SUMS" "$dir/SHA256SUMS"
mapfile -t names < <(awk '{print $2}' "$dir/SHA256SUMS")
[ "${#names[@]}" -gt 0 ] || die "SHA256SUMS is empty"
for name in "${names[@]}"; do
  fetch "$base/$name" "$dir/$name"
done

# 2. checksums
(cd "$dir" && sha256sum --check --strict SHA256SUMS)

# 3. attestations
# The API returns each bundle either inline or, since 2026, as a bundle_url
# pointing at raw-snappy-compressed JSON (GitHub's own CLI decodes it with
# snappy.Decode); `snzip -d -t raw` is the equivalent here.
fetch_bundle() { # ATTESTATIONS_JSON INDEX OUT
  local json="$1" i="$2" out="$3" url
  if [ "$(jq -r ".attestations[$i].bundle // empty | type" "$json")" = "object" ]; then
    jq ".attestations[$i].bundle" "$json" >"$out"
    return
  fi
  url="$(jq -r ".attestations[$i].bundle_url // empty" "$json")"
  [ -n "$url" ] || die "attestation $i has neither bundle nor bundle_url"
  curl -fsSL --retry 6 --retry-delay 5 --retry-all-errors -o "$out.sn" "$url" || die "cannot download bundle $url"
  snzip -d -t raw <"$out.sn" >"$out" || die "cannot decompress bundle (raw snappy expected)"
  rm -f "$out.sn"
}

predicate_type() { # BUNDLE
  jq -r '.dsseEnvelope.payload' "$1" | base64 -d | jq -r '.predicateType'
}

verify_attestation() { # NAME DIGEST PREDICATE_TYPE LABEL
  local name="$1" digest="$2" ptype="$3" label="$4" json bundle i n found=0
  json="$dir/$name.attestations.json"
  curl -fsSL --retry 6 --retry-delay 5 --retry-all-errors "${auth[@]}" \
    -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
    -o "$json" "$api/repos/$repo/attestations/sha256:$digest?per_page=100" ||
    die "$name: cannot fetch attestations for sha256:$digest"
  n="$(jq '.attestations | length' "$json")"
  [ "$n" -gt 0 ] || die "$name: no attestations recorded for sha256:$digest"
  for ((i = 0; i < n; i++)); do
    bundle="$dir/$name.$i.sigstore.json"
    [ -f "$bundle" ] || fetch_bundle "$json" "$i" "$bundle"
    [ "$(predicate_type "$bundle")" = "$ptype" ] || continue
    cosign verify-blob-attestation \
      --bundle "$bundle" \
      --certificate-oidc-issuer "$issuer" \
      --certificate-identity "$identity" \
      --type "$ptype" \
      "$dir/$name" >/dev/null 2>"$dir/$name.$label.cosign.log" ||
      {
        cat "$dir/$name.$label.cosign.log" >&2
        die "$name: $label attestation did NOT verify"
      }
    found=1
  done
  [ "$found" -eq 1 ] || die "$name: no $label attestation ($ptype) found"
  echo "verify-release: $name: $label attestation OK (identity $identity)"
}

while read -r digest name; do
  verify_attestation "$name" "$digest" "$provenance_type" provenance
  verify_attestation "$name" "$digest" "$sbom_type" sbom
done <"$dir/SHA256SUMS"

# 4. independent reproduction
if [ "$rebuild" -eq 1 ]; then
  echo "verify-release: rebuilding release assets from $tag with Nix"
  out="$(nix build "github:$repo/$tag#release-assets" --no-link --print-out-paths)"
  diff "$out/SHA256SUMS" "$dir/SHA256SUMS" || die "rebuilt assets differ from the published ones"
  echo "verify-release: rebuild reproduced SHA256SUMS bit-for-bit"
fi

echo "verify-release: $tag verified: checksums, provenance and SBOM attestations${rebuild:+, reproducibility}"
