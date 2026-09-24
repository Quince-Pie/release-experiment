# Security

## Reporting a vulnerability

Use GitHub's private vulnerability reporting for this repository
(Security tab → "Report a vulnerability"). Do not open a public issue for
anything that could be exploitable. Reports are acknowledged within seven
days; fixes ship as a new patch release with a `### Security` entry in
`CHANGELOG.md`.

## Release integrity

Every release of this project is designed to be verifiable without
trusting the maintainer's machine, the CI service, or GitHub's UI:

| Guarantee | Mechanism | How to check |
| --- | --- | --- |
| The release corresponds to a source revision chosen by a maintainer | Annotated git tag `vX.Y.Z`, SSH-signed by a key in `allowed_signers`; CI refuses anything else (`scripts/verify-tag.sh`) | `git -c gpg.ssh.allowedSignersFile=allowed_signers verify-tag vX.Y.Z` |
| The binaries were built from that revision by this repository's release workflow | GitHub artifact attestations (SLSA provenance v1, Sigstore-signed with the workflow's OIDC identity) | `nix run .#verify -- vX.Y.Z` (or `cosign verify-blob-attestation`, see `scripts/verify-release.sh`) |
| The binaries contain what the SBOM says | SPDX SBOM attestation over the same subjects | same command |
| Nobody, including the maintainer, can swap assets after publication | GitHub immutable releases (enabled for this repository); the tag ruleset blocks tag updates and deletions | Release page shows the immutable badge; `GET /repos/…/immutable-releases` |
| Anyone can rebuild the identical bytes | Reproducible Nix build; CI rebuilds on x86_64 and arm64 and after `--rebuild` requires identical `SHA256SUMS` | `nix run .#verify -- --rebuild vX.Y.Z` |

`SHA256SUMS` is included with each release for consumers without cosign or
Nix; it is itself a subject of nothing, so prefer the attestations when you
can verify them.

## Signing keys

Release tags must be signed with an SSH key listed in `allowed_signers`
(OpenSSH `ssh-keygen -Y` format, `git` namespace). Adding or rotating a key
is a pull request to that file, reviewed like any other change; CI verifies
tags against the file at the tagged commit, so a key becomes valid for
releases only after its addition has been merged.

Maintainer setup:

```sh
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
git config tag.gpgSign true
git config commit.gpgsign true
git config gpg.ssh.allowedSignersFile "$PWD/allowed_signers"
```

Register the same public key on GitHub as a *signing* key (Settings → SSH
and GPG keys → New SSH key → key type "Signing Key") so the web UI shows
"Verified"; CI verification does not depend on that registration.

## Supply-chain controls in this repository

- All GitHub Actions are pinned to full commit SHAs, and the repository
  setting "Require actions to be pinned to a full-length commit SHA" is on.
  Only GitHub-owned actions and `ossf/scorecard-action` are allowed to run.
- Workflows start from `permissions: {}`; the default `GITHUB_TOKEN`
  permission is read-only; write scopes are granted per job and commented.
- Nix is installed by `scripts/install-nix.sh` from `releases.nixos.org`
  with a pinned version and SHA-256, not by a third-party action.
- Every dependency is locked: `flake.lock` (nixpkgs), the upstream Go
  toolchain tarball hash (`nix/go-toolchain.nix`), `go.mod`, action SHAs and
  the Nix installer hash. Updates
  arrive as pull requests (Dependabot, `flake-update.yml`).
- `zizmor` (pedantic), `actionlint`, `shellcheck`, `govulncheck`, CodeQL
  (Go and Actions) and OpenSSF Scorecard run in CI.
