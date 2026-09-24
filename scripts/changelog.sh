#!/usr/bin/env bash
# changelog.sh - Keep a Changelog 2.0.0 helper for CHANGELOG.md.
#
#   changelog.sh lint                       validate structure, versions, order, links
#   changelog.sh latest                     print the latest released version
#   changelog.sh section VERSION|Unreleased print the body of one section
#   changelog.sh unreleased-empty           exit 0 if [Unreleased] has no entries
#   changelog.sh release VERSION [DATE]     move [Unreleased] into "## [VERSION] - DATE"
#
# CHANGELOG.md is the single source of truth for the project version; the
# flake, the binary and the release tag are all validated against it.
# Requires `relver` (this repository's own tool) for SemVer validation.
set -euo pipefail

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}
CHANGELOG="${CHANGELOG:-$(repo_root)/CHANGELOG.md}"

release_re='^## \[([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?)\] - ([0-9]{4}-[0-9]{2}-[0-9]{2})( \[YANKED\])?$'
allowed_types='Added|Changed|Deprecated|Removed|Fixed|Security'

die() {
  echo "changelog: $*" >&2
  exit 1
}

need_relver() {
  command -v relver >/dev/null 2>&1 || die "relver not in PATH (use 'nix develop' or 'nix run .#changelog')"
}

# Repository web URL used for compare links, derived from the origin remote.
repo_url() {
  if [ -n "${CHANGELOG_REPO_URL:-}" ]; then
    printf '%s\n' "$CHANGELOG_REPO_URL"
    return
  fi
  local url
  url="$(git remote get-url origin 2>/dev/null || true)"
  case "$url" in
    git@*:*)
      url="${url#git@}"
      url="https://${url/:/\/}"
      ;;
    ssh://git@*) url="https://${url#ssh://git@}" ;;
  esac
  url="${url%.git}"
  [ -n "$url" ] || die "cannot determine repository URL; set CHANGELOG_REPO_URL"
  printf '%s\n' "$url"
}

cmd_latest() {
  local line
  while IFS= read -r line; do
    if [[ $line =~ $release_re ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done <"$CHANGELOG"
  return 1
}

# Body of a section: lines after its heading up to the next "## " heading,
# with leading/trailing blank lines removed.
cmd_section() {
  local want="$1"
  awk -v want="$want" '
    /^## \[/ {
      if (found) exit
      heading = $0
      sub(/^## \[/, "", heading); sub(/\].*$/, "", heading)
      if (heading == want) { found = 1; next }
    }
    found && /^\[[^]]+\]: / { next }
    found { buf[n++] = $0 }
    END {
      if (!found) exit 3
      start = 0; end = n
      while (start < end && buf[start] ~ /^[[:space:]]*$/) start++
      while (end > start && buf[end-1] ~ /^[[:space:]]*$/) end--
      for (i = start; i < end; i++) print buf[i]
    }' "$CHANGELOG" || {
    rc=$?
    [ "$rc" -eq 3 ] && die "no section for '$want' in $CHANGELOG"
    exit "$rc"
  }
}

cmd_unreleased_empty() {
  [ -z "$(cmd_section Unreleased)" ]
}

cmd_lint() {
  need_relver
  [ -f "$CHANGELOG" ] || die "$CHANGELOG not found"
  local -a versions=()
  local line n=0 seen_unreleased=0 first_h2="" prev_h3="" prev_line="" errors=0
  local -A refs=()
  err() {
    echo "changelog: line $n: $*" >&2
    errors=$((errors + 1))
  }
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if [ "$n" -eq 1 ] && [ "$line" != "# Changelog" ]; then
      err "first line must be '# Changelog'"
    fi
    case "$line" in
      '## '*)
        [ -z "$first_h2" ] && first_h2="$line"
        if [ "$line" = "## [Unreleased]" ]; then
          seen_unreleased=$((seen_unreleased + 1))
        elif [[ $line =~ $release_re ]]; then
          versions+=("${BASH_REMATCH[1]}")
          date -u -d "${BASH_REMATCH[3]}" +%F >/dev/null 2>&1 || err "invalid date in '$line'"
        else
          err "malformed section heading '$line' (want '## [X.Y.Z] - YYYY-MM-DD')"
        fi
        ;;
      '### '*)
        [[ $line =~ ^###\ ($allowed_types)$ ]] || err "unknown change type '$line' (Keep a Changelog allows: ${allowed_types//|/, })"
        ;;
      '['*']: '*)
        refs["${line%%]*}"]=1
        [[ ${line#*]: } =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?/ ]] || err "malformed link reference URL in '$line'"
        ;;
    esac
    # A "### Type" heading directly followed by another heading is an empty subsection.
    if [[ $prev_h3 != "" && $line =~ ^##\ ?(#)?\  ]] && [[ $prev_line =~ ^[[:space:]]*$ ]]; then
      err "empty subsection '$prev_h3'"
    fi
    case "$line" in
      '### '*) prev_h3="$line" ;;
      '#'*) prev_h3="" ;;
      *) [[ $line =~ ^[[:space:]]*$ ]] || prev_h3="" ;;
    esac
    prev_line="$line"
  done <"$CHANGELOG"

  [ "$seen_unreleased" -eq 1 ] || err "exactly one '## [Unreleased]' section is required (found $seen_unreleased)"
  [ "$first_h2" = "## [Unreleased]" ] || err "'## [Unreleased]' must be the first section"
  [ -n "${refs['[Unreleased']:-}" ] || err "missing link reference '[Unreleased]: <url>'"

  local v prev=""
  for v in "${versions[@]}"; do
    relver check "$v" || err "invalid SemVer 2.0.0 version '$v'"
    [ -n "${refs["[$v"]:-}" ] || err "missing link reference '[$v]: <url>'"
    if [ -n "$prev" ] && [ "$(relver compare "$prev" "$v")" != "1" ]; then
      err "versions must be strictly descending: '$prev' is not newer than '$v'"
    fi
    prev="$v"
  done

  [ "$errors" -eq 0 ] || die "$errors problem(s) found in $CHANGELOG"
  echo "changelog: OK ($CHANGELOG, ${#versions[@]} release(s), latest: ${versions[0]:-none})"
}

cmd_release() {
  need_relver
  local ver="${1:-}" date="${2:-$(date -u +%F)}" latest base link tmp
  [ -n "$ver" ] || die "usage: changelog.sh release VERSION [DATE]"
  relver check "$ver" || die "'$ver' is not a valid SemVer 2.0.0 version (no leading 'v')"
  cmd_lint >/dev/null
  cmd_unreleased_empty && die "[Unreleased] is empty; nothing to release"
  latest="$(cmd_latest || true)"
  if [ -n "$latest" ]; then
    [ "$(relver compare "$ver" "$latest")" = "1" ] || die "'$ver' must be newer than latest release '$latest'"
  fi
  base="$(repo_url)"
  if [ -n "$latest" ]; then
    link="$base/compare/v$latest...v$ver"
  else
    link="$base/releases/tag/v$ver"
  fi
  tmp="$(mktemp)"
  awk -v ver="$ver" -v date="$date" -v base="$base" -v link="$link" '
    state == 0 && $0 == "## [Unreleased]" {
      print; print ""; print "## [" ver "] - " date; state = 1; next
    }
    /^\[Unreleased\]: / {
      print "[Unreleased]: " base "/compare/v" ver "...HEAD"
      print "[" ver "]: " link
      seen_ref = 1; next
    }
    { print }
    END {
      if (!seen_ref) {
        print ""
        print "[Unreleased]: " base "/compare/v" ver "...HEAD"
        print "[" ver "]: " link
      }
    }' "$CHANGELOG" >"$tmp"
  mv "$tmp" "$CHANGELOG"
  cmd_lint >/dev/null
  echo "changelog: released $ver ($date) in $CHANGELOG"
}

case "${1:-}" in
  lint) cmd_lint ;;
  latest) cmd_latest ;;
  section) cmd_section "${2:?usage: changelog.sh section VERSION|Unreleased}" ;;
  unreleased-empty) cmd_unreleased_empty ;;
  release) shift && cmd_release "$@" ;;
  *)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
