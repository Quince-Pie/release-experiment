# 0006. Hardening the GitHub side: pins, permissions, immutability, rules

Status: accepted (2026-09-24). Evidence: [`docs/evidence.md`](../evidence.md) E5–E6.

## Threats addressed

- A third-party action's tag is moved to malicious code (the mechanism of
  the March 2025 `tj-actions/changed-files` compromise): every `uses:` is
  a full commit SHA, and the repository setting *Require actions to be
  pinned to a full-length commit SHA* is on, so a future unpinned edit is
  rejected by the platform, not only by review. Only GitHub-owned actions
  and `ossf/scorecard-action` are allowed to run at all.
- A compromised job token: workflows start from `permissions: {}`, the
  repository default for `GITHUB_TOKEN` is read-only, and every write
  scope is granted per job with a comment naming what needs it
  (`contents: write` only in the publish job; `id-token`/`attestations`
  only there too).
- A third-party installer for Nix: `scripts/install-nix.sh` downloads the
  versioned official installer from `releases.nixos.org`, checks its
  SHA-256 against a value committed here, and lets the installer check the
  tarball against the hash embedded in itself. The trust set for CI is
  {GitHub, nixos.org, go.dev}, all of which the build already depends on.
- Retroactive changes to a release: immutable releases are enabled
  (`PUT /repos/{o}/{r}/immutable-releases`), so a published release's
  tag, assets and notes are frozen; the tag ruleset blocks updates and
  deletions of `v*` tags and restricts their creation to administrators.
- Script injection in workflows: no `${{ }}` inside `run:`; values go
  through `env:`. `zizmor --persona pedantic` (offline in `nix flake
  check`, online with impostor-commit and known-vulnerable-action audits
  in CI) and `actionlint` gate every change; CodeQL's Actions and Go
  analyses run through the default setup; OpenSSF Scorecard runs weekly.
- Drift: Dependabot updates action SHAs and the Go module weekly;
  `flake-update.yml` updates `flake.lock` through a GitHub-signed commit
  and a pull request, dispatching CI explicitly because pushes made with
  `GITHUB_TOKEN` do not trigger workflows.

## Branch and tag rules (created through the REST API)

- `main`: no deletion, no force-push, linear history, pull request
  required (squash or rebase), required checks `nix flake check
  (ubuntu-24.04)`, `nix flake check (ubuntu-24.04-arm)`,
  `Cross-architecture reproducibility`, `govulncheck`, `zizmor (online
  audits)`; administrators may bypass, and every bypass is audit-logged.
- `refs/tags/v*`: creation restricted to administrators, no updates, no
  deletions. The SemVer name pattern is enforced by `scripts/verify-tag.sh`
  because the `tag_name_pattern` rule is not offered to repositories
  outside Team/Enterprise organizations.
- Not enabled yet: *require signed commits*. GitHub only verifies
  signatures from keys registered on the account; the maintainer's SSH
  key is registered for authentication but not as a signing key, so the
  rule would block every push. CI's tag verification is independent of
  GitHub's badge. Enable the rule after registering the key.

## Why not `ubuntu-latest`

Runner images are pinned (`ubuntu-24.04`, `ubuntu-24.04-arm`) so that an
image rollover cannot silently change the build environment; the build
itself runs inside Nix's sandbox and does not depend on the image beyond
`curl`, `tar`, `xz` and `sudo`.
