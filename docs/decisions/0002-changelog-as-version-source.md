# 0002. `CHANGELOG.md` is the single source of the version

Status: accepted (2026-09-24). Evidence: `nix/version.nix`, `scripts/changelog.sh`,
the version self-check in `nix/package.nix`.

## The question

Where is "the version" stored, such that the tag, the build, the binary and
the release notes cannot disagree?

## Candidates

| Source | Problem |
| --- | --- |
| The git tag only (`git describe`) | A Nix flake evaluates a source tree without its tags, so the build cannot know its own version; `git describe` output also differs between a full clone and a shallow one. |
| A `VERSION` file (or a version field in a manifest) | Two things must be bumped together, the file and the tag; every release tool grows a check for the mismatch, and the release notes live somewhere else again. |
| Inference from commit messages (Conventional Commits) | The version becomes a function of prose discipline rather than of the change; a mislabelled commit silently produces a wrong major or minor. The judgement that a change is breaking belongs to a person reading the diff, or to an API-diff tool, not to a prefix. |
| **The topmost released section of `CHANGELOG.md`** | The file must be edited for every release anyway; the heading carries the version and the date, the section carries the notes. |

## Decision

`CHANGELOG.md` follows Keep a Changelog 2.0.0 (2026-06-07), whose format is
unchanged from 1.1.0: six change types, `YYYY-MM-DD` dates, `[Unreleased]`
and `[YANKED]` markers, and a link reference per version. Its new guidance
is adopted too: a short **Breaking:** marker on entries that break users,
and no "Dependencies" type ("Dependencies are not a type of change").
The first `## [X.Y.Z] - YYYY-MM-DD` heading is the version. Everything else is derived:

- `nix/version.nix` parses the file at evaluation time. If `[Unreleased]`
  is empty the checkout *is* the release and the version is `X.Y.Z`;
  otherwise the checkout is a development snapshot and gets a Go-style
  pseudo-version that sorts after `X.Y.Z` and before the next release
  (`X.Y.(Z+1)-0.<UTC timestamp>-<12 hex of the commit>`, or
  `X.Y.Z-pre.0.…` after a pre-release, or `0.0.0-…` before any release).
  These are valid SemVer 2.0.0 strings, so every consumer orders them
  correctly, and they never collide with a real release.
- The binary's `relver version` prints that value, and the build fails
  if it does not (`versionCheckHook`).
- The release tag must equal `v` + that value (`scripts/verify-tag.sh`).
- The release notes and the tag message are that section
  (`scripts/changelog.sh section`).
- `scripts/changelog.sh lint` runs in `nix flake check`: exactly one
  `[Unreleased]` section first, well-formed headings with ISO dates, valid
  SemVer versions in strictly descending order, only the six Keep a
  Changelog change types, no empty subsections, a link reference for every
  version.
- A pull request must touch `CHANGELOG.md` unless labelled
  `skip-changelog`, which keeps the "empty `[Unreleased]` means release
  state" invariant honest.

## Consequences

- Cutting a release is a text edit that `scripts/changelog.sh release`
  performs mechanically: move `[Unreleased]` under a dated heading, fix the
  compare links.
- Because the version is read at evaluation time, `nix build` on any
  commit reports a version that identifies that commit; nothing depends
  on a `.git` directory being present.
- The scheme is language-agnostic. For ecosystems whose manifests carry a
  version (Cargo, npm), a lint that the manifest equals the changelog
  heading is the only addition.
