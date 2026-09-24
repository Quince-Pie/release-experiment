# release-experiment

[![CI](https://github.com/Quince-Pie/release-experiment/actions/workflows/ci.yml/badge.svg)](https://github.com/Quince-Pie/release-experiment/actions/workflows/ci.yml)
[![Release](https://github.com/Quince-Pie/release-experiment/actions/workflows/release.yml/badge.svg)](https://github.com/Quince-Pie/release-experiment/actions/workflows/release.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/Quince-Pie/release-experiment/badge)](https://scorecard.dev/viewer/?uri=github.com/Quince-Pie/release-experiment)

A reference implementation of a verifiable software release on GitHub (and,
in its host-independent core, on any git server): what a release *is*, what
triggers it, how it is built, attested, published and checked, with every
decision argued from primary sources and tested in this repository. The
reasoning lives in [`docs/decisions`](docs/decisions) and the experiments in
[`docs/evidence.md`](docs/evidence.md).

The release artifact is `relver`, a small Semantic Versioning 2.0.0 tool
(`check`, `compare`, `sort`, `next`, `version`) that the release process
itself uses to validate versions.

## The release contract

| | |
| --- | --- |
| **Version** | Semantic Versioning 2.0.0. The topmost released section of [`CHANGELOG.md`](CHANGELOG.md) (Keep a Changelog 2.0.0) is the single source of truth; the flake, the binary and the tag are validated against it. Development builds get a Go-style pseudo-version such as `0.1.1-0.20260924055703-c010f8c68505` that sorts correctly between releases. |
| **Trigger** | A pushed annotated tag `vX.Y.Z`, SSH-signed by a key listed in [`allowed_signers`](allowed_signers), pointing at a commit on `main` whose changelog names exactly that version and has an empty `[Unreleased]` section. Nothing else publishes: not the release UI, not `workflow_dispatch`, not a bot. |
| **Build** | `nix build .#release-assets`: six archives (linux/darwin/windows × amd64/arm64) built with the upstream Go toolchain pinned by hash, packed deterministically, plus `SHA256SUMS`. Two runners of different architectures must produce identical bytes, each also rebuilt in place, before anything is published; stock Go outside Nix reproduces the same bytes. |
| **Publish** | Build provenance (SLSA v1) and an SPDX SBOM are attested with GitHub's Sigstore integration; the release is created as a draft through the REST API, every asset is uploaded and checked against the server-computed digest, and only then is it published. Immutable releases are enabled, so the tag and the assets cannot change afterwards (notes stay editable). |
| **Verify** | A separate job downloads the published release as a consumer would, checks `SHA256SUMS`, verifies both attestations with cosign against the identity of this repository's release workflow for this tag, and rebuilds the assets from the tag to confirm they match. |

## Verify a release

```sh
nix run github:Quince-Pie/release-experiment#verify -- 0.1.0             # checksums + attestations
nix run github:Quince-Pie/release-experiment#verify -- --rebuild 0.1.0   # ... and an independent rebuild
```

Without Nix: download `SHA256SUMS` and the archive, run `sha256sum --check`,
then fetch the attestation for the archive's digest from
`GET /repos/Quince-Pie/release-experiment/attestations/sha256:<digest>`,
decompress the `bundle_url` payload (`snzip -d -t raw`) and run

```sh
cosign verify-blob-attestation --bundle bundle.json \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity https://github.com/Quince-Pie/release-experiment/.github/workflows/release.yml@refs/tags/v0.1.0 \
  --type https://slsa.dev/provenance/v1 relver_0.1.0_linux_amd64.tar.gz
```

[`scripts/verify-release.sh`](scripts/verify-release.sh) is exactly that,
plus the SBOM attestation and the rebuild. No `gh` CLI is involved anywhere.

## Cut a release

```sh
nix run .#release -- prepare minor      # or: prepare 1.2.0
# ... merge the "Release v1.2.0" pull request ...
nix run .#release -- tag 1.2.0          # signed tag; CI takes it from here
```

`prepare` rotates `[Unreleased]` into a dated section, commits and opens
the pull request; `tag` creates and verifies the signed annotated tag and
pushes it. Repositories that allow direct pushes can do both at once with
`prepare 1.2.0 --direct`. The version is a human decision; nothing infers
it from commit messages. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Layout

```
CHANGELOG.md              the version and the release notes (Keep a Changelog 2.0.0)
allowed_signers           SSH keys whose tag signatures are accepted as releases
flake.nix, nix/           toolchain, package, cross builds, release assets, checks, apps
cmd/relver, internal/     the Go program and its tests
scripts/                  release.sh, verify-tag.sh, changelog.sh, github-release.sh,
                          verify-release.sh, sbom.sh, install-nix.sh
.github/workflows/        ci.yml, release.yml, scorecard.yml
.github/dependabot.yml    updates for actions, the Go module and flake.lock
docs/research/            the primary-source research digests behind the decisions
docs/decisions/           the reasoning, one decision per file
docs/evidence.md          what was measured and observed while building this
SECURITY.md               guarantees, how to check each, how to report
```

`nix develop` provides every tool used above; `nix flake check` runs what CI
runs: build and tests, `go vet`/`gofmt`, treefmt, the changelog lint,
shellcheck/shfmt and actionlint/zizmor.

## Decisions

| Question | Decision | Why, in one line | Details |
| --- | --- | --- | --- |
| Versioning scheme | SemVer 2.0.0; tags `vX.Y.Z` | Every consumer that resolves versions (Go, Cargo, npm, Nix, GitHub's "latest") understands SemVer precedence; CalVer encodes time, which the tag date already records, and its zero-padded forms are not even valid SemVer | [0001](docs/decisions/0001-versioning.md) |
| Where the version lives | `CHANGELOG.md` | One place that humans must touch anyway; a `VERSION` file drifts from the tag, a tag-only scheme is invisible to Nix | [0002](docs/decisions/0002-changelog-as-version-source.md) |
| Release trigger | Signed annotated tag, verified in CI | Portable to every git host; the human signature is the trust anchor; release-first and dispatch-first flows publish before assets exist or move the anchor to whoever can click | [0003](docs/decisions/0003-signed-tag-trigger.md) |
| Build and reproducibility | Upstream Go via Nix, `dontFixup`, two-architecture identity | nixpkgs' Go and stdenv fixups make output depend on the build host; with stock Go the bytes depend only on source, version and flags | [0004](docs/decisions/0004-reproducible-build.md) |
| Attestation and verification | GitHub artifact attestations, verified with cosign through the REST API | Provenance and SBOM are bound to the exact workflow identity and tag; verification needs no GitHub tooling | [0005](docs/decisions/0005-attestations.md) |
| Platform hardening | SHA-pinned actions with the pin policy enforced, `permissions: {}`, first-party Nix install, immutable releases, rulesets | Removes the mechanisms of the 2025 action-compromise incidents; nothing can be changed after publication | [0006](docs/decisions/0006-github-hardening.md) |
| Release tooling | None adopted; eight small scripts wrapped as flake apps | Every candidate either infers versions from commit messages, needs a standing write token to trigger workflows, publishes before uploading, or is ecosystem-bound; GoReleaser is the credible alternative for projects without a Nix build | [0007](docs/decisions/0007-release-tooling.md) |
| Other git hosts | Tag + changelog + scripts carry over; only the release adapter changes | The host-specific part is one script | [0008](docs/decisions/0008-other-hosts.md) |

## Known limits

- GitHub shows the maintainer's signatures as "Unverified" until the SSH
  key is registered as a *signing* key on the account; CI verification does
  not depend on that, but a "require signed commits" rule does, so it is
  not enabled yet.
- The extra release attestation GitHub creates for immutable releases
  (`in-toto.io/attestation/release/v0.2`) carries only a timestamp, no
  transparency-log entry; cosign 3.1.3 cannot verify it against GitHub's
  published trusted root. The provenance and SBOM attestations this
  repository creates itself verify fully.
- The API rejected a tag-name-pattern rule for this user-owned repository;
  the SemVer name pattern is enforced by CI instead.
