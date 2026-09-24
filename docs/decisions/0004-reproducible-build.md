# 0004. Reproducible builds with the upstream Go toolchain, orchestrated by Nix

Status: accepted (2026-09-24). Evidence: [`docs/evidence.md`](../evidence.md) E1–E3.

## Requirement

A release artifact must be reproducible in three senses, from weakest to
strongest:

1. the same machine rebuilding the same derivation gets the same bytes
   (`nix build --rebuild`);
2. independent builders, of different CPU architectures, get the same bytes
   (the two-runner gate in CI);
3. anyone with the toolchain and the source, **without Nix**, gets the same
   bytes (`go build` with the documented flags).

Sense 3 is what makes "verify the provenance, then rebuild it yourself" a
real option for a consumer, and it is what the SLSA source/build tracks
call "verified reproducible". Sense 1 alone is nearly free with Nix and
proves little.

## What was tried and what happened

- `buildGoModule` from nixpkgs (Go 1.26.7 from nixpkgs): sense 1 held;
  sense 2 failed for all six targets. Diffing the binaries showed two
  independent causes: nixpkgs patches the standard library to embed the
  store paths of `tzdata`, `iana-etc` and `mailcap` (platform-specific
  hashes), and stdenv's fixup runs `strip`/`patchelf` on native ELF outputs
  only, rewriting the section layout. Sense 3 is impossible with a patched
  toolchain by construction.
- Upstream go1.27.1 tarball from go.dev (hash-pinned per build platform),
  built with a 60-line `mkDerivation`, `dontFixup = true`,
  `GOFLAGS=-trimpath -buildvcs=false -mod=mod`, `CGO_ENABLED=0`,
  `-ldflags "-s -w -buildid= -X ..."`: senses 1, 2 and 3 all hold
  (CI run on commit b6dcad5; local stock-Go comparison for linux/amd64 and
  windows/arm64).

## Decision

- The Go toolchain is the official distribution, pinned by SHA-256 in
  `nix/go-toolchain.nix`. nixpkgs itself bootstraps Go from these tarballs,
  so this adds no trust root that a nixpkgs-based build does not already
  have; it removes nixpkgs' patches from the artifact.
- The build recipe is explicit (`nix/package.nix`) rather than
  `buildGoModule`: no vendoring machinery is needed for a dependency-free
  program, and a release artifact should be produced by a recipe short
  enough to audit and to repeat by hand.
- Nix never post-processes the linker output (`dontFixup`). Stripping is
  done by the linker (`-s -w`), which is deterministic.
- `-buildvcs=false`: the commit is passed through `-X main.commit`, so a
  checkout with `.git` and the `.git`-less Nix source link identically.
- Archive packing is deterministic (`nix/release-assets.nix`): ustar,
  sorted members, numeric owner 0, mtimes and zip DOS times from the
  commit timestamp, `gzip -n`, sorted zip members.
- CI builds the assets on `ubuntu-24.04` and `ubuntu-24.04-arm`, rebuilds
  each in place with `--rebuild`, and the release job refuses to publish
  unless both `SHA256SUMS` are identical. The consumer-side verifier's
  `--rebuild` performs a third, post-publication reproduction on a fresh
  runner.

## Consequences

- The Go version is pinned in two places that must agree: `go.mod`'s
  language version (a lower bound) and `nix/go-toolchain.nix` (the exact
  toolchain). Toolchain bumps are ordinary pull requests with the hashes
  refreshed from `https://go.dev/dl/?mode=json&include=all`.
- The toolchain tarball (~70 MB) is fetched from go.dev on every fresh
  runner; it is a fixed-output derivation, so it is verified by hash and is
  not served by cache.nixos.org. Measured cost is a few seconds.
- `pkgs.go` and `gopls` from nixpkgs remain in the dev shell for editor
  tooling; nothing in the release path uses them.
