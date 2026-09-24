# Evidence log

Experiments run while building this repository, with what they showed.
Each entry states the hypothesis, the method, the result and where the
data can be re-examined. Numbers are from the actual runs; nothing here is
inferred from documentation alone.

## E1. Nix `--rebuild` reproduces the release assets on one machine

- Hypothesis: `packages.release-assets` (six archives + `SHA256SUMS`) is
  deterministic.
- Method: `nix build .#release-assets` then `nix build .#release-assets
  --rebuild`, which rebuilds the derivation and fails if any output byte
  differs. Run locally (x86_64-linux) and in every CI job.
- Result: identical on every run, with both the original nixpkgs-Go build
  and the upstream-Go build. This is the weakest form of reproducibility
  (same machine, same store) and was never the problem.

## E2. Two builders of different architectures did not agree (first design)

- Hypothesis: the x86_64 and arm64 GitHub-hosted runners produce identical
  assets for the same commit.
- Method: CI job matrix `ubuntu-24.04` / `ubuntu-24.04-arm`, each building
  `release-assets`; a third job diffs the two `SHA256SUMS`.
  Runs 35961846289 (SHA256SUMS only) and 35962213021 (full assets) on
  commit c010f8c.
- Result: all six archives differed. A local build on a third x86_64
  machine matched the x86_64 runner exactly, so the divergence was
  host-architecture dependent, not machine dependent.
- Diagnosis from the artifacts (binaries extracted from both builders):
  - Mach-O targets: sizes equal, 31 (amd64) and 63 (arm64) differing
    bytes, all inside the string
    `/nix/store/<hash>-tzdata-2026c/share/zoneinfo`. nixpkgs' `go` applies
    `tzdata-1.19.patch`, `iana-etc-1.25.patch` and `mailcap-1.17.patch`
    (see `pkgs/development/compilers/go/1.26.nix`), embedding per-platform
    store paths into the standard library.
  - ELF targets: additionally, the *native* binary on each host had its
    section header table at the end of the file (`e_shoff` 0x1e3e90) and
    a 16-byte-rounded data segment, while the cross-built binary kept the
    Go linker's layout (`e_shoff` 0x158). The Go linker source
    (`cmd/link/internal/ld/elf.go`, go1.26.7, unchanged by nixpkgs) only
    ever places section headers after the program headers, so the native
    binary had been rewritten after linking: stdenv's default fixup phase
    runs `strip`/`patchelf` on host-architecture ELF files and skips
    foreign ones.
  - PE targets: 1,681,803 differing bytes and a 512-byte size difference,
    consistent with both effects.
- Consequence: builds with nixpkgs' Go cannot be identical across build
  platforms, and cannot be reproduced by anyone using stock Go.

## E3. Upstream Go toolchain, `dontFixup`, `-buildvcs=false`

- Change: `nix/go-toolchain.nix` fetches the official go1.27.1 tarball
  from go.dev pinned by SHA-256 (the same tarballs nixpkgs bootstraps Go
  from); `nix/package.nix` builds with a minimal `mkDerivation`,
  `dontFixup = true`, `GOFLAGS=-trimpath -buildvcs=false -mod=mod`,
  `CGO_ENABLED=0`, `-ldflags "-s -w -buildid= -X ..."`.
- Result (local, x86_64-linux): native ELF `e_shoff` is 0x158 (the
  linker's own layout); `strings` finds zero `/nix/store` occurrences in
  the binary; `--rebuild` identical.
- Stock-Go reproduction: the same commit built **outside Nix** with the
  downloaded go1.27.1 and the same flags is byte-identical to the Nix
  output for linux/amd64 and windows/arm64. Without `-buildvcs=false` the
  outside build differed from byte 209 onward because `go build` embeds
  `vcs.revision`/`vcs.time`/`vcs.modified` when a `.git` directory is
  present and the Nix source has none.
- CI run 35963718077 (commit 01bce67): `nix flake check` on both runners,
  `--rebuild` on both, and the `Cross-architecture reproducibility` job
  found the two builders' `SHA256SUMS` identical. This identity is
  re-checked on every push and gates every release
  (`.github/workflows/release.yml`, job `publish`).

## E4. GitHub artifact attestations can be verified without `gh`

- Method: `GET /repos/cli/cli/attestations/sha256:<digest>` for a release
  asset of cli/cli v2.101.0, then `cosign verify-blob-attestation` 3.1.3.
- Findings:
  - The API returned `bundle: null` and a `bundle_url` per attestation.
    The URL serves `Content-Type: application/x-snappy`: the Sigstore
    bundle JSON compressed with raw snappy. GitHub's own CLI decodes it
    with `snappy.Decode` (`pkg/cmd/attestation/api/client.go`); `snzip -d
    -t raw` is the command-line equivalent and is what
    `scripts/verify-release.sh` uses. The release asset object also
    carries a server-computed `digest` field, which
    `scripts/github-release.sh` checks after every upload.
  - The workflow-created provenance bundle (`https://slsa.dev/provenance/v1`,
    certificate SAN `https://github.com/cli/cli/.github/workflows/deployment.yml@refs/heads/trunk`,
    one Rekor entry) verified: `Verified OK`.
  - Immutable releases add a second, GitHub-initiated attestation per
    asset: predicate type `https://in-toto.io/attestation/release/v0.2`
    with `purl`, `tag`, `repository` and ids, certificate SAN
    `https://dotcom.releases.github.com`, issued by `O=GitHub, Inc.,
    CN=Fulcio Intermediate l1`, **no** OIDC-issuer extension, **no**
    transparency-log entry and one RFC 3161 timestamp. GitHub's trusted
    root is published through its TUF repository
    (`https://tuf-repo.github.com`, target `trusted_root.json`, verified
    against `10.targets.json`); it lists four Fulcio CAs and four
    timestamp authorities. cosign 3.1.3 could not verify this bundle with
    that root (`pkcs7: No certificate for signer` for the timestamp; and
    it refuses `--timestamp-certificate-chain` together with
    `--trusted-root`). GitHub's CLI verifies it with sigstore-go using
    `verify.WithSignedTimestamps(1)`. This repository therefore verifies
    the provenance and SBOM attestations it creates itself, and documents
    the release attestation as an additional server-side guarantee whose
    independent verification currently needs a sigstore-go-based verifier.

## E5. Repository settings reachable through the REST API

Confirmed by making the calls (all returned 2xx and read back):

- `PUT /repos/{o}/{r}/immutable-releases` enables immutable releases;
  `GET` returns `{"enabled":true,"enforced_by_owner":false}`.
- `PUT /repos/{o}/{r}/actions/permissions` accepts
  `"sha_pinning_required": true` alongside `allowed_actions`.
- `PUT /repos/{o}/{r}/actions/permissions/selected-actions` with
  `github_owned_allowed` and `patterns_allowed`;
  `PUT .../actions/permissions/workflow` with
  `default_workflow_permissions: read`.
- `PATCH /repos/{o}/{r}/code-scanning/default-setup` enables CodeQL for
  `go` and `actions` (only after code exists; it returns 422 on an empty
  repository).
- `POST /repos/{o}/{r}/rulesets`: a branch ruleset (deletion,
  non_fast_forward, required_linear_history, pull_request,
  required_status_checks) and a tag ruleset (creation, update, deletion)
  were created. `tag_name_pattern` was rejected with `Validation Failed`
  and an empty reason; metadata rules are not offered to repositories
  outside Team/Enterprise organizations, so the tag name pattern is
  enforced by `scripts/verify-tag.sh` in CI instead.
- Commit signature status: a commit signed with the maintainer's SSH key
  is reported as `"verified": false, "reason": "unknown_key"` until the
  key is registered on the account as a *signing* key. Because of that,
  `required_signatures` is not part of the branch ruleset yet; CI
  verification of tag signatures does not depend on GitHub's badge.

## E6. First-party Nix installation on hosted runners

- `scripts/install-nix.sh` downloads the versioned installer from
  `releases.nixos.org` (Nix 2.35.2, SHA-256 pinned in the script), runs a
  multi-user install and adds the profile to `GITHUB_PATH`.
- Result: succeeded on `ubuntu-24.04` and `ubuntu-24.04-arm` in every run;
  `nix flake check` with sandboxing enabled passed on both.

## E7. The first real `prepare` exposed a defect the simulation had masked

- Running `nix run .#release -- prepare 0.1.0` against the real remote
  produced changelog reference links of the form
  `https///github.com:Quince-Pie/...`: the SSH-remote conversion in
  `scripts/changelog.sh` prefixed `https://` before replacing the first
  colon. The earlier end-to-end simulation (E-series above) had set
  `CHANGELOG_REPO_URL` and never exercised that branch of the code.
- Fix: replace the colon first; and the changelog lint now rejects any
  reference whose URL is not `scheme://host/...`, so a malformed link
  fails `nix flake check` and the pull request's CI rather than reaching
  a tag. The release branch was rebuilt from the fixed main and the
  pull request re-checked before merging.

## E8. v0.1.0: a tag without a release, by design

- The tag was created and pushed by `nix run .#release -- tag 0.1.0`;
  GitHub reports its signature as `unknown_key` (see E5) while
  `scripts/verify-tag.sh` accepts it. Release run 35965234379 verified the
  tag, built and rebuilt the assets on both architectures, and confirmed
  the built version equals the tag, then failed on the next guard:
  `nix eval --raw .#lib.versionInfo.isRelease` cannot print a boolean
  ("cannot coerce a Boolean to a string"). That step only runs for tag
  pushes, so the `workflow_dispatch` dry run had not exercised it.
- A re-run cannot help: a workflow run uses the workflow file at the
  tagged commit. Moving the tag is what the rules forbid, so v0.1.0 stays
  a tag with no release and v0.1.1 carries the fix (`nix eval --json`),
  together with a second correction found while reviewing the untested
  publish path: `make_latest` is now sent on the publish call rather than
  on the draft, since GitHub documents that drafts cannot be set as
  latest. The SPDX predicate type the verifier expects
  (`https://spdx.dev/Document/v2.3`) was confirmed against
  `actions/attest`'s source (`https://spdx.dev/Document/v${spdxVersion}`).

## E9. v0.1.1: the first published release, verified three ways

- Flow as documented: `nix run .#release -- prepare 0.1.1` opened pull
  request #2; nine checks passed (the five required ones plus CodeQL for
  Go and Actions and the changelog rule); the squash merge produced a
  GitHub-verified commit; `nix run .#release -- tag 0.1.1` created the
  SSH-signed annotated tag, verified it locally and pushed it.
- Release run 35965737315: `Verify tag and build` 1.5 min (x86_64) and
  1.1 min (arm64) in parallel, `Attest and publish` 0.9 min, `Verify as
  a consumer` 1.4 min; about five minutes end to end.
- Published release: `immutable: true`; ten assets (six archives,
  `SHA256SUMS`, the SPDX SBOM, the provenance and SBOM Sigstore
  bundles), each with a server-computed `sha256` digest that
  `scripts/github-release.sh` compared against the local file at upload;
  `GET /releases/latest` returns v0.1.1.
- Attestations per archive, read back through the API: a provenance
  statement (`https://slsa.dev/provenance/v1`) and an SBOM statement
  (`https://spdx.dev/Document/v2.3`), both with certificate SAN
  `https://github.com/Quince-Pie/release-experiment/.github/workflows/release.yml@refs/tags/v0.1.1`,
  plus GitHub's release attestation
  (`https://in-toto.io/attestation/release/v0.2`, SAN
  `https://dotcom.releases.github.com`, initiator `github`).
- Independent consumer verification from a third machine, using the
  flake from GitHub at the tag rather than a local checkout
  (`nix run github:Quince-Pie/release-experiment/v0.1.1#verify -- --rebuild 0.1.1`):
  `SHA256SUMS` matches, all twelve cosign verifications pass, and the
  rebuild from the tag reproduces `SHA256SUMS` bit-for-bit. Together with
  the two CI builders that is three independent reproductions of the
  published bytes on two CPU architectures.
