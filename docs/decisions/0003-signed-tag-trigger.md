# 0003. The release trigger is a signed annotated tag, verified in CI

Status: accepted (2026-09-24). Evidence: [`docs/evidence.md`](../evidence.md) E5; the
simulated release flow and the negative tests in `scripts/verify-tag.sh`.

## The question

Something has to say "this revision is version X.Y.Z, publish it". The
candidates differ in *who* says it, *what* records it, and *when* assets
become visible relative to the release object.

## Candidates

| Trigger | Who authorises | What records it | Failure modes found |
| --- | --- | --- | --- |
| Release created in the web UI or API, workflow on `release: published` | anyone with write access, by clicking | a release object; GitHub creates a *lightweight, unsigned* tag if none exists | The release exists and the `release` webhook fires before any asset exists; with immutable releases assets cannot be added after publishing at all, so the workflow would have to publish a second release or fail. The trust anchor is a click. |
| `workflow_dispatch` with a version input, CI creates the tag | anyone who can dispatch | a tag created by `GITHUB_TOKEN`, unsigned | The tag is created by the platform token, so it is exactly as trustworthy as the CI configuration; nothing a human signed connects the version to a revision. Also, events created by `GITHUB_TOKEN` do not trigger other workflows, so tag-driven consumers never see it. |
| Release pull request (release-please, release-plz style) | the person who merges | a merge commit; a bot then tags and releases | Needs a token stronger than `GITHUB_TOKEN` (an App or PAT) for the bot's tag to trigger anything; the version is inferred from commit messages; the tag is unsigned or signed by a bot key. Host-specific machinery. |
| **Annotated tag signed by a maintainer, pushed; CI verifies and builds** | the holder of a listed signing key | a git object that every host and every clone carries; the signature covers the tag name, the target commit and the message | Requires a local command and a key; a failed build leaves a tag without a release (handled below). |

## Decision

A release exists when `refs/tags/vX.Y.Z` points at a commit reachable from
`main`, the tag object is annotated and SSH-signed by a key in
`allowed_signers`, and `CHANGELOG.md` at that commit names `X.Y.Z` as its
latest release with an empty `[Unreleased]` section. `scripts/verify-tag.sh`
is the single definition of that predicate; the maintainer's `release.sh
tag` runs it before pushing, the release workflow runs it before building,
and a consumer can run it against a clone.

Why this wins on the objectives:

- **Supply chain.** The anchor is a human signature over a git object,
  independent of the hosting platform's UI, tokens or badges. GitHub's
  rulesets add that only administrators can create `v*` tags and nobody
  can move or delete them; CI adds that only listed keys count. A stolen
  CI token cannot mint a release; a stolen platform password cannot
  either without the signing key.
- **Correctness.** The version is decided by a human, who is the only
  party that can judge Semantic Versioning compatibility; the tag,
  the changelog and the binary's `--version` are forced to agree; assets
  are uploaded to a draft and the release is published last, so no
  observer ever sees a release without its assets, which is also the only
  order immutable releases allow.
- **Portability.** Annotated, signed tags and `git verify-tag` exist on
  every git host; the "release object" is the only host-specific part.
- **Ease.** Two commands (`prepare`, `tag`), or one with `--direct`; the
  scripts refuse to proceed on a dirty tree, an out-of-date branch, a
  missing key, a wrong version or an already existing tag.

## Consequences and edge cases

- If the workflow fails after the tag is pushed, the tag stays. A version
  names a source snapshot; if that snapshot does not build, the next
  version fixes it. Moving tags is exactly the practice the rules forbid.
  `nix flake check` runs locally in `prepare` (through the pull request's
  CI) before a tag is ever created, so this is rare.
- Pre-releases are ordinary tags (`v1.0.0-rc.1`); the release is marked
  as a pre-release and is not "latest".
- Yanked releases are recorded in `CHANGELOG.md` (`[YANKED]`), not by
  deleting anything.
- The signing key's registration on GitHub only affects the "Verified"
  badge and GitHub's own signature rules; the process does not depend on
  it.
