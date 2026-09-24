# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The topmost released section is the single source of truth for the version:
the flake, the binary and the release tag are all derived from it.

## [Unreleased]

## [0.1.0] - 2026-09-24

### Added

- `relver`, a Semantic Versioning 2.0.0 tool (`check`, `compare`, `sort`,
  `next`, `version`) built for linux, darwin and windows on amd64 and arm64.
- A release process triggered only by a signed annotated tag: reproducible
  builds checked on two CPU architectures and against stock Go, SLSA
  provenance and SPDX SBOM attestations, and immutable GitHub releases.
- `nix run .#verify`, a consumer-side verifier for checksums, attestations
  and reproducibility that needs no GitHub tooling.

[Unreleased]: https://github.com/Quince-Pie/release-experiment/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Quince-Pie/release-experiment/releases/tag/v0.1.0
