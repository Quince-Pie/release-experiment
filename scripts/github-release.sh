#!/usr/bin/env bash
# github-release.sh - publish a GitHub release for a tag with the REST API.
#
#   github-release.sh TAG ASSET_DIR
#
# Creates a DRAFT release, uploads every file in ASSET_DIR, verifies each
# upload against the server-reported digest, and only then publishes the
# release. Publishing last means consumers (and the `release` webhook) never
# observe a release without its assets, and it is the only order that works
# with immutable releases, which freeze assets at publish time.
#
# Environment: GITHUB_TOKEN (contents: write), GITHUB_REPOSITORY (owner/repo),
# optional GITHUB_API_URL (default https://api.github.com).
# Re-running after a failure is safe: a stale draft for the same tag is
# replaced; an already published release is never touched.
set -euo pipefail

tag="${1:?usage: github-release.sh TAG ASSET_DIR}"
dir="${2:?usage: github-release.sh TAG ASSET_DIR}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
api="${GITHUB_API_URL:-https://api.github.com}"
root="$(git rev-parse --show-toplevel)"

die() {
  echo "github-release: $*" >&2
  exit 1
}

gh_api() { # METHOD PATH [curl args...]
  local method="$1" path="$2"
  shift 2
  curl -sS --fail-with-body -X "$method" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$api$path" "$@"
}

version="${tag#v}"
prerelease=false
case "$version" in *-*) prerelease=true ;; esac
notes="$(bash "$root/scripts/changelog.sh" section "$version")"

# Refuse to touch a published release; drop a stale draft from an earlier attempt.
existing="$(gh_api GET "/repos/$GITHUB_REPOSITORY/releases?per_page=100")"
if [ "$(jq -r --arg t "$tag" '[.[] | select(.tag_name == $t and .draft == false)] | length' <<<"$existing")" != "0" ]; then
  die "a published release for $tag already exists; releases are immutable, cut a new version instead"
fi
for id in $(jq -r --arg t "$tag" '.[] | select(.tag_name == $t and .draft == true) | .id' <<<"$existing"); do
  echo "github-release: deleting stale draft release $id"
  gh_api DELETE "/repos/$GITHUB_REPOSITORY/releases/$id" >/dev/null
done

# Mark as "latest" only if this version orders above every published
# non-pre-release version. GitHub documents three different rules for the
# automatic choice (semantic version in the UI docs, created_at in the REST
# docs, date-then-version for make_latest=legacy), so decide explicitly.
make_latest=false
if [ "$prerelease" = false ]; then
  make_latest=true
  while read -r other; do
    [ -n "$other" ] || continue
    if relver check "$other" >/dev/null 2>&1 && [ "$(relver compare "$version" "$other")" != "1" ]; then
      make_latest=false
    fi
  done < <(jq -r '.[] | select(.draft == false and .prerelease == false) | .tag_name | ltrimstr("v")' <<<"$existing")
fi

# 1. draft
payload="$(jq -n --arg tag "$tag" --arg name "$tag" --arg body "$notes" --argjson pre "$prerelease" --arg latest "$make_latest" \
  '{tag_name:$tag, name:$name, body:$body, draft:true, prerelease:$pre, make_latest:$latest}')"
release="$(gh_api POST "/repos/$GITHUB_REPOSITORY/releases" -d "$payload")"
id="$(jq -r .id <<<"$release")"
upload_url="$(jq -r '.upload_url | sub("\\{\\?name,label\\}$"; "")' <<<"$release")"
echo "github-release: created draft release $id for $tag"

# 2. assets, each verified against the digest GitHub computed server-side
for file in "$dir"/*; do
  [ -f "$file" ] || continue
  name="$(basename "$file")"
  local_sha="$(sha256sum "$file" | cut -d' ' -f1)"
  asset="$(curl -sS --fail-with-body -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$file" \
    "$upload_url?name=$name")"
  state="$(jq -r .state <<<"$asset")"
  remote_sha="$(jq -r '.digest // empty' <<<"$asset")"
  size="$(jq -r .size <<<"$asset")"
  [ "$state" = "uploaded" ] || die "asset $name: state=$state"
  [ "$size" = "$(stat -c %s "$file")" ] || die "asset $name: size mismatch"
  if [ -n "$remote_sha" ] && [ "$remote_sha" != "sha256:$local_sha" ]; then
    die "asset $name: server digest $remote_sha != local sha256:$local_sha"
  fi
  echo "github-release: uploaded $name (${size} bytes, sha256:$local_sha)"
done

# 3. publish (this is the point of no return with immutable releases)
published="$(gh_api PATCH "/repos/$GITHUB_REPOSITORY/releases/$id" -d '{"draft": false}')"
echo "github-release: published $(jq -r .html_url <<<"$published")"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "release_id=$id"
    echo "html_url=$(jq -r .html_url <<<"$published")"
  } >>"$GITHUB_OUTPUT"
fi
