#!/usr/bin/env bash
# release.sh - cut a release from the command line, in two auditable steps.
#
#   release.sh prepare VERSION|major|minor|patch [--direct] [--date YYYY-MM-DD]
#       Rotate [Unreleased] into "## [VERSION] - DATE" in CHANGELOG.md and
#       commit "Release vVERSION". By default the commit goes to a branch
#       release/vVERSION which is pushed and turned into a pull request, so
#       branch protection and CI apply. With --direct (repositories that
#       allow direct pushes) the commit AND the signed tag are pushed to main
#       atomically in one step.
#
#   release.sh tag VERSION
#       After the release commit is on main: create the signed, annotated
#       tag vVERSION whose message is the changelog section, verify it with
#       scripts/verify-tag.sh, and push it. Pushing the tag is what triggers
#       the release workflow; nothing else does.
#
# The tag is the release trigger and the human signature is the trust
# anchor. CI never creates tags or signs anything with long-lived keys.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
branch="${RELEASE_BRANCH:-main}"
remote="${RELEASE_REMOTE:-origin}"

die() {
  echo "release: $*" >&2
  exit 1
}

require_clean() {
  [ -z "$(git status --porcelain)" ] || die "working tree is not clean"
}

require_signing() {
  git config --get user.signingkey >/dev/null || die "user.signingkey is not set (see SECURITY.md: 'Signing keys')"
  local fmt
  fmt="$(git config --get gpg.format || echo openpgp)"
  [ "$fmt" = "ssh" ] || [ "$fmt" = "openpgp" ] || die "unsupported gpg.format '$fmt'"
}

sync_branch() {
  git fetch --quiet --tags "$remote"
  [ "$(git rev-parse --abbrev-ref HEAD)" = "$branch" ] || die "not on $branch"
  [ "$(git rev-parse HEAD)" = "$(git rev-parse "$remote/$branch")" ] ||
    die "$branch is not in sync with $remote/$branch (pull or push first)"
}

resolve_version() {
  local arg="$1" latest
  case "$arg" in
    major | minor | patch)
      latest="$(bash scripts/changelog.sh latest || true)"
      [ -n "$latest" ] || die "no previous release to bump; give an explicit VERSION"
      relver next "$arg" "$latest"
      ;;
    v*) die "give the version without the leading 'v'" ;;
    *)
      relver check "$arg" >/dev/null || die "'$arg' is not a valid SemVer 2.0.0 version"
      printf '%s\n' "$arg"
      ;;
  esac
}

# GitHub adapter: open a pull request through the REST API (no gh CLI).
# Silently skipped when no token is available; the compare URL is printed instead.
open_pull_request() {
  local head="$1" ver="$2" url owner_repo token body
  url="$(git remote get-url "$remote")"
  case "$url" in
    git@github.com:*) owner_repo="${url#git@github.com:}" ;;
    https://github.com/*) owner_repo="${url#https://github.com/}" ;;
    ssh://git@github.com/*) owner_repo="${url#ssh://git@github.com/}" ;;
    *)
      echo "release: non-GitHub remote; open the merge request manually for branch $head"
      return 0
      ;;
  esac
  owner_repo="${owner_repo%.git}"
  token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  if [ -z "$token" ] && [ -f .env ]; then
    token="$(sed -n 's/^GH_TOKEN=//p' .env | tr -d '"' | head -n1)"
  fi
  if [ -z "$token" ]; then
    echo "release: no GH_TOKEN; open the pull request here:"
    echo "  https://github.com/$owner_repo/compare/$branch...$head?expand=1"
    return 0
  fi
  # shellcheck disable=SC2016  # backticks are Markdown in the PR body, not command substitution
  body="$(jq -n --arg t "Release v$ver" --arg h "$head" --arg b "$branch" \
    --arg body "$(printf 'Finalize CHANGELOG.md for v%s.\n\nAfter merging, run: `nix run .#release -- tag %s`' "$ver" "$ver")" \
    '{title:$t, head:$h, base:$b, body:$body}')"
  curl -sSf -X POST \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$owner_repo/pulls" \
    -d "$body" | jq -r '"release: pull request opened: \(.html_url)"'
}

cmd_prepare() {
  local ver="" direct=0 date=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --direct) direct=1 ;;
      --date)
        shift
        date="${1:-}"
        ;;
      -*) die "unknown option $1" ;;
      *) ver="$1" ;;
    esac
    shift
  done
  [ -n "$ver" ] || die "usage: release.sh prepare VERSION|major|minor|patch [--direct] [--date DATE]"
  require_clean
  require_signing
  sync_branch
  ver="$(resolve_version "$ver")"
  git rev-parse -q --verify "refs/tags/v$ver" >/dev/null && die "tag v$ver already exists"

  bash scripts/changelog.sh release "$ver" ${date:+"$date"}
  git add CHANGELOG.md
  git commit --quiet -S -m "Release v$ver" -m "Move the [Unreleased] changelog entries under v$ver."
  echo "release: committed $(git rev-parse --short HEAD) 'Release v$ver'"

  if [ "$direct" -eq 1 ]; then
    create_tag "$ver"
    git push --atomic "$remote" "$branch" "v$ver"
    echo "release: pushed $branch and v$ver atomically; the release workflow is now running"
  else
    local head="release/v$ver"
    git branch --force "$head" HEAD
    git reset --quiet --hard "$remote/$branch"
    git push --force-with-lease "$remote" "$head"
    open_pull_request "$head" "$ver"
    echo "release: after the pull request is merged run:  nix run .#release -- tag $ver"
  fi
}

create_tag() {
  local ver="$1" notes
  notes="$(bash scripts/changelog.sh section "$ver")"
  git tag --sign --annotate "v$ver" -m "v$ver" -m "$notes"
  bash scripts/verify-tag.sh "v$ver" HEAD
}

cmd_tag() {
  local ver="${1:-}"
  [ -n "$ver" ] || die "usage: release.sh tag VERSION"
  relver check "$ver" >/dev/null || die "'$ver' is not a valid SemVer 2.0.0 version"
  require_clean
  require_signing
  sync_branch
  [ "$(bash scripts/changelog.sh latest)" = "$ver" ] || die "CHANGELOG.md latest release is not $ver; merge the release commit first"
  bash scripts/changelog.sh unreleased-empty || die "[Unreleased] is not empty on $branch"
  git rev-parse -q --verify "refs/tags/v$ver" >/dev/null && die "tag v$ver already exists locally"
  git ls-remote --exit-code --tags "$remote" "refs/tags/v$ver" >/dev/null 2>&1 && die "tag v$ver already exists on $remote"
  create_tag "$ver"
  git push "$remote" "v$ver"
  echo "release: pushed v$ver; the release workflow builds, attests and publishes it"
}

case "${1:-}" in
  prepare) shift && cmd_prepare "$@" ;;
  tag) shift && cmd_tag "$@" ;;
  *)
    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
