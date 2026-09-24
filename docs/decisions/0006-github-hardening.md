# 0006. Hardening the GitHub side: pins, permissions, immutability, rules

Status: accepted (2026-09-24). Evidence: [`docs/evidence.md`](../evidence.md) E5–E6.
Research: [`docs/research/r3-gh-actions.md`](../research/r3-gh-actions.md),
[`docs/research/r2-gh-releases.md`](../research/r2-gh-releases.md).

## Threats and the control for each

- **A third-party action's tag is moved to malicious code.** This was the
  mechanism of `tj-actions/changed-files` (CVE-2025-30066, March 2025),
  `reviewdog/action-setup` (CVE-2025-30154) and, in March 2026, the
  Trivy compromise (CVE-2026-33634: 76 of 77 `trivy-action` tags
  force-pushed to infostealer commits). Every `uses:` here is a
  full commit SHA, and the repository policy *Require actions to be pinned
  to a full-length commit SHA* (`sha_pinning_required` in the REST API,
  available since 2025-08-15) makes the platform reject an unpinned edit.
  GitHub's "Immutable Actions" programme, which would have made tags
  immutable, was stopped in 2025 in favour of exactly this policy, so SHA
  pinning is the only immutable reference today. Only GitHub-owned
  actions and `ossf/scorecard-action` are allowed to run.
- **A compromised job token.** Workflows start from `permissions: {}`,
  the repository default for `GITHUB_TOKEN` is read-only, and every write
  scope is granted per job with a comment naming what needs it:
  `contents: write` only in the publish job; `id-token: write` and
  `attestations: write` only there too. No personal access token or App
  token exists anywhere in the pipeline.
- **A third-party installer for the build tool.** `scripts/install-nix.sh`
  downloads the versioned official installer from `releases.nixos.org`,
  checks it against a SHA-256 committed here, and lets the installer check
  the tarball against the hash embedded in itself. The trust set for CI is
  {GitHub, nixos.org, go.dev}, all already relied on by the build. The
  common alternatives were examined: `DeterminateSystems/nix-installer-action`
  installs Determinate Nix by default (`determinate: true`), a downstream
  distribution; `cachix/install-nix-action` runs the same official
  installer this script runs; `nixbuild/nix-quick-install-action` does a
  single-user install without sandboxing. None adds anything the script
  lacks, and each adds a vendor to trust.
- **Retroactive changes to a release.** Immutable releases are enabled
  (`PUT /repos/{o}/{r}/immutable-releases`; GA 2025-10-28): at publish
  "its assets can't be added, modified, or deleted" and "tags for new
  immutable releases are protected and can't be deleted or moved". Title,
  notes and the pre-release/latest flags remain editable, which is the
  right boundary: bytes are frozen, prose is not. The tag ruleset
  independently blocks updates and deletions of `v*` tags and restricts
  their creation to administrators.
- **Script injection.** No `${{ }}` inside `run:`; values pass through
  `env:`. `zizmor --persona pedantic` (offline in `nix flake check`,
  online in CI with impostor-commit and known-vulnerable-action audits),
  `actionlint`, CodeQL's Actions analysis (GA 2025-04-22) and OpenSSF
  Scorecard gate every change. `pull_request_target` is not used;
  GitHub disables it by default for public repositories from 2026-11-02.
- **Drift.** Dependabot updates the action SHAs (rewriting the trailing
  version comment), the Go module and, since 2026-04-07, the `flake.lock`
  inputs, with the platform's 3-day cooldown; its pull requests run CI
  under a first-party identity. A custom `nix flake update` workflow was
  built first and removed once this was verified: it needed a
  GitHub-signed commit through GraphQL and an explicit CI dispatch to work
  around the rule that `GITHUB_TOKEN` pushes trigger nothing.

## Branch and tag rules (created through the REST API)

- `main`: no deletion, no force-push, linear history, pull request
  required (squash or rebase, review threads resolved), required checks
  `nix flake check (ubuntu-26.04)`, `nix flake check (ubuntu-26.04-arm)`,
  `Cross-architecture reproducibility`, `govulncheck`, `zizmor (online
  audits)`; administrators may bypass, and every bypass is audit-logged.
- `refs/tags/v*`: creation restricted to administrators, no updates, no
  deletions. The API rejected a `tag_name_pattern` rule for this
  user-owned repository, so the SemVer name pattern is enforced by
  `scripts/verify-tag.sh`.
- Not enabled yet: *require signed commits*. GitHub verifies signatures
  only from keys registered on the account; the maintainer's SSH key is
  registered for authentication, not as a signing key, so the rule would
  block every push (the API reports the signed commits as
  `unknown_key`). CI's tag verification does not depend on GitHub's
  badge. Register the key, then enable the rule. Also worth enabling once
  it is exposed through the API: the workflow execution protections (GA
  2026-09-17) that limit `workflow_dispatch` to maintainers.

## Runners

Images are pinned to `ubuntu-26.04` and `ubuntu-26.04-arm` (both GA
2026-09-17; `ubuntu-latest` moves to 26.04 between 2026-10-19 and
2026-11-19) rather than `ubuntu-latest`, so an image rollover cannot
silently change the environment. Linux arm64 hosted runners are free for
public repositories (GA 2025-08-07), which is what makes the
two-architecture reproducibility gate affordable. The build itself runs
inside Nix's sandbox and needs only `curl`, `tar`, `xz` and `sudo` from
the image. All actions in use run on Node 24 or are composite; Node 20
was removed from runners on 2026-09-23.

## Sources

GitHub Docs: security hardening for Actions, managing Actions settings
(SHA pinning), REST Actions permissions, workflow syntax (permissions),
events that trigger workflows, immutable releases, rulesets and available
rules, REST rules, SSH signing keys; GitHub Changelog entries of
2025-08-15 (SHA-pinning policy), 2025-10-28 (immutable releases GA),
2026-04-07 (Dependabot Nix), 2026-06-18 and 2026-09-17 (workflow execution
protections), 2026-09-17 (Ubuntu 26.04), 2025-09-19 (Node 20 removal),
2025-08-07 (arm64 runners); GitHub community discussion by the Actions
product lead on Immutable Actions (2025-12-16); GHSA/CVE advisories for
tj-actions, reviewdog, Trivy, TanStack and Nx; CISA alerts of 2025-03-18
and 2026-05-28. All accessed 2026-09-24; URLs in the research digests.
