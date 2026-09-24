#!/usr/bin/env bash
# verify-tag.sh - decide whether a git tag is a legitimate release tag.
#
#   verify-tag.sh TAG [MAIN_REF]
#
# A tag is accepted only if ALL of the following hold:
#   1. it is an annotated tag object (not a lightweight ref);
#   2. it carries a valid SSH signature from a key listed in allowed_signers;
#   3. its name is "v" + the topmost released version in CHANGELOG.md at the
#      tagged commit, and the [Unreleased] section there is empty;
#   4. the tagged commit is reachable from MAIN_REF (default: origin/main).
# The same script runs locally before pushing and in CI before building, so
# there is exactly one definition of "valid release tag".
set -euo pipefail

tag="${1:?usage: verify-tag.sh TAG [MAIN_REF]}"
main_ref="${2:-origin/main}"
root="$(git rev-parse --show-toplevel)"
signers="${ALLOWED_SIGNERS:-$root/allowed_signers}"

die() {
  echo "verify-tag: $tag: $*" >&2
  exit 1
}

[ -f "$signers" ] || die "allowed signers file not found: $signers"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null || die "tag does not exist"

# 1. annotated
[ "$(git cat-file -t "refs/tags/$tag")" = "tag" ] || die "not an annotated tag (use 'git tag -s')"

# 2. signature by an allowed signer (SSH signatures need the allowed-signers file)
git -c gpg.ssh.allowedSignersFile="$signers" verify-tag "$tag" 2>/tmp/verify-tag.$$ ||
  {
    cat /tmp/verify-tag.$$ >&2
    rm -f /tmp/verify-tag.$$
    die "signature is missing or not from an allowed signer"
  }
rm -f /tmp/verify-tag.$$

# 3. name matches CHANGELOG.md at the tagged commit
commit="$(git rev-parse "$tag^{commit}")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git show "$commit:CHANGELOG.md" >"$tmp/CHANGELOG.md"
latest="$(CHANGELOG="$tmp/CHANGELOG.md" bash "$root/scripts/changelog.sh" latest)" || die "no released version in CHANGELOG.md at $commit"
[ "$tag" = "v$latest" ] || die "tag name does not match CHANGELOG.md latest release v$latest"
CHANGELOG="$tmp/CHANGELOG.md" bash "$root/scripts/changelog.sh" unreleased-empty ||
  die "[Unreleased] section is not empty at the tagged commit"
case "$tag" in
  v[0-9]*) ;;
  *) die "tag must look like vX.Y.Z" ;;
esac

# 4. reachable from main
git merge-base --is-ancestor "$commit" "$main_ref" || die "tagged commit $commit is not reachable from $main_ref"

echo "verify-tag: $tag OK (commit $commit, signed by allowed key, matches CHANGELOG.md)"
