# 0007. Release tooling: none adopted; the process is eight small scripts

Status: accepted (2026-09-24). Research: [`docs/research/r5-tools.md`](../research/r5-tools.md)
(27 tools vetted against their own documentation and repository metadata on 2026-09-24).

## What a tool would have to do

Given [0001](0001-versioning.md)–[0003](0003-signed-tag-trigger.md), the
release process has five mechanical steps: rotate the changelog, create a
signed tag, verify the tag, build and attest reproducibly, publish
draft-first. A candidate tool earns its place if it does some of these
better than a script, without changing who decides the version, which
token can trigger what, or the draft-then-publish order that immutable
releases require.

## Findings that eliminate whole categories

- **Every release-pull-request tool documents that its own pull requests,
  tags and releases trigger nothing** when created with `GITHUB_TOKEN`
  (release-please: "all resources created by release-please … will not
  trigger future GitHub actions workflows"; release-plz: "the default
  GITHUB_TOKEN cannot trigger other workflow runs"; commitizen: "treated
  like [skip ci]"; update-flake-lock and knope recipes ask for a PAT). The
  documented remedy is a personal access token or a GitHub App token, which
  is a standing write credential the design here does not need.
- **Commit-message inference of the version** (release-please,
  semantic-release, git-cliff `--bump`, cocogitto, commitizen,
  python-semantic-release, svu) is rejected by [0001](0001-versioning.md):
  the compatibility judgement is a property of the change, not of a
  prefix. Changesets and knope's change files record a human intent per
  change, which is sound, but they exist for JavaScript and multi-package
  workspaces.
- **Publish-then-upload ordering** breaks under immutable releases. Tools
  that create the release first and upload later (taiki-e's
  create-gh-release + upload-rust-binary pair, python-semantic-release's
  publish action, release-please with a separate upload step) cannot add
  assets after publication; GitHub prescribes "Create the release as a
  draft. Attach all associated assets to the draft release. Publish the
  draft release." GoReleaser, softprops/action-gh-release v3 and
  ncipollo/release-action (`immutableCreate`) do this correctly.
- **Archived or deprecated**: `actions/create-release` and
  `actions/upload-release-asset` (archived, last push 2021-03-03,
  "currently unmaintained"); `standard-version` ("deprecated",
  recommends release-please).

## The strongest challenger: GoReleaser v2

GoReleaser (v2.18.2, 2026-09-17, actively maintained) is the most complete
tool for this shape of project: tag-triggered, always drafts first, ships
checksums, cosign signing, syft SBOMs, an `actions/attest-build-provenance`
example, and a v2.18 preflight that "aborts the release before building
if … the current tag is already published as an immutable release". It was
not adopted because:

1. It would own the build. Its builders invoke `go build` on the runner;
   the reproducibility argument here rests on the Nix-orchestrated,
   hash-pinned toolchain and on rebuilding on two architectures
   ([0004](0004-reproducible-build.md)). GoReleaser can consume prebuilt
   binaries, but then most of what it adds is packaging that
   `nix/release-assets.nix` already does deterministically.
2. It is one more binary in the trust set of the publish job (installed by
   a third-party action or from a release), with Pro-only features
   (nightlies, monorepos, notarisation) marking where the open-source
   surface ends.
3. Its value is largest for projects that need Homebrew casks, Scoop,
   nfpm packages, Docker images and multiple registries. This project
   publishes archives and attestations; the delta is small.

For a Go project with those distribution needs and without a Nix build,
GoReleaser is the right answer and its immutable-release handling is
correct.

## Decision

The eight scripts in `scripts/` (about 700 lines of bash, shellcheck- and
shfmt-clean, each wrapped as a flake app with its pinned tools) implement
the process with no dependency beyond git, curl, jq, coreutils, cosign,
snzip and syft. What they replace, and why the replacement is smaller:

| Step | Tool it replaces | Why the script |
| --- | --- | --- |
| Changelog rotation and lint | git-cliff, towncrier, commitizen changelog | The changelog is human-written (Keep a Changelog); rotation is a 20-line awk program; the lint uses `relver` for the version rules |
| Tag creation and verification | cargo-release `sign-tag`, GoReleaser (none verifies) | `git tag --sign` plus one verification predicate shared by maintainer and CI |
| Release creation and upload | softprops/action-gh-release, ncipollo/release-action | Two REST calls plus one upload loop, with the server digest checked per asset, no third-party action in the `contents: write` job |
| Attestation | cosign-installer + cosign, slsa-github-generator (no longer maintained) | GitHub-owned `actions/attest-build-provenance` and `actions/attest` |
| Verification | `gh attestation verify`, `gh release verify` | cosign against the attestations API, which any consumer can run |
| Dependency updates | Renovate, update-flake-lock | Dependabot now covers actions, Go modules and Nix flake inputs with a first-party identity whose pull requests trigger CI |

## Sources

Tool documentation and repository metadata as listed in the research
digest (release-please, semantic-release, changesets, git-cliff,
GoReleaser, release-plz, cargo-release, knope, cocogitto, commitizen,
python-semantic-release, towncrier, softprops/action-gh-release,
ncipollo/release-action, release-drafter, cargo-dist, svu,
conventional-changelog, taiki-e actions, mikepenz, actions/create-release,
Renovate, Dependabot, DeterminateSystems actions). GitHub Docs:
"Triggering a workflow" (GITHUB_TOKEN rule), "Immutable releases". All
accessed 2026-09-24.
