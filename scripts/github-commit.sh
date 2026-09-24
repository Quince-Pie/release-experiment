#!/usr/bin/env bash
# github-commit.sh - commit files to a branch through the GitHub GraphQL API.
#
#   github-commit.sh BRANCH MESSAGE FILE...
#
# Commits created with createCommitOnBranch are signed by GitHub, so they
# satisfy a "require signed commits" rule, which commits pushed from a
# workflow with GITHUB_TOKEN cannot. The branch is created from the default
# branch when it does not exist yet. Files are read from the working tree
# and committed at the same relative paths.
#
# Environment: GITHUB_TOKEN (contents: write), GITHUB_REPOSITORY.
set -euo pipefail

branch="${1:?usage: github-commit.sh BRANCH MESSAGE FILE...}"
message="${2:?usage: github-commit.sh BRANCH MESSAGE FILE...}"
shift 2
[ $# -gt 0 ] || {
  echo "github-commit: no files given" >&2
  exit 2
}
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
api="${GITHUB_API_URL:-https://api.github.com}"
graphql="${GITHUB_GRAPHQL_URL:-$api/graphql}"

gh_api() { # METHOD PATH [curl args...]
  local method="$1" path="$2"
  shift 2
  curl -sS --fail-with-body -X "$method" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$api$path" "$@"
}

head="$(gh_api GET "/repos/$GITHUB_REPOSITORY/git/ref/heads/$branch" 2>/dev/null | jq -r '.object.sha // empty' || true)"
if [ -z "$head" ]; then
  default="$(gh_api GET "/repos/$GITHUB_REPOSITORY" | jq -r .default_branch)"
  head="$(gh_api GET "/repos/$GITHUB_REPOSITORY/git/ref/heads/$default" | jq -r .object.sha)"
  gh_api POST "/repos/$GITHUB_REPOSITORY/git/refs" \
    -d "$(jq -n --arg ref "refs/heads/$branch" --arg sha "$head" '{ref:$ref, sha:$sha}')" >/dev/null
  echo "github-commit: created branch $branch from $default@${head:0:12}"
fi

additions="$(for f in "$@"; do
  jq -n --arg path "$f" --arg contents "$(base64 -w0 "$f")" '{path:$path, contents:$contents}'
done | jq -s .)"

# shellcheck disable=SC2016  # $input is a GraphQL variable, not a shell expansion
query='mutation($input: CreateCommitOnBranchInput!) {
  createCommitOnBranch(input: $input) { commit { oid url } }
}'
variables="$(jq -n --arg repo "$GITHUB_REPOSITORY" --arg branch "$branch" --arg head "$head" \
  --arg headline "${message%%$'\n'*}" --arg body "${message#*$'\n'}" --argjson additions "$additions" '
  {input: {
    branch: {repositoryNameWithOwner: $repo, branchName: $branch},
    expectedHeadOid: $head,
    message: ({headline: $headline} + (if $body != $headline then {body: $body} else {} end)),
    fileChanges: {additions: $additions}
  }}')"

response="$(curl -sS --fail-with-body -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" -H "Content-Type: application/json" \
  "$graphql" -d "$(jq -n --arg query "$query" --argjson variables "$variables" '{query:$query, variables:$variables}')")"
oid="$(jq -r '.data.createCommitOnBranch.commit.oid // empty' <<<"$response")"
[ -n "$oid" ] || {
  echo "github-commit: failed: $(jq -c '.errors // .' <<<"$response")" >&2
  exit 1
}
echo "github-commit: $branch -> $oid ($(jq -r .data.createCommitOnBranch.commit.url <<<"$response"))"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "sha=$oid" >>"$GITHUB_OUTPUT"
fi
