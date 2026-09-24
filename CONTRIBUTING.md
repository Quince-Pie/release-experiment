# Contributing

## Development environment

Everything is provided by the flake; nothing needs to be installed globally.

```sh
nix develop            # Go, cosign, syft, actionlint, zizmor, shellcheck, treefmt, relver, ...
nix flake check        # what CI runs: build, tests, vet, formatting, changelog, workflow and script lint
nix fmt                # format Nix, Go and shell files
nix build .#release-assets && ls result/   # the exact archives a release would publish
```

## Changes

- Every pull request that changes behaviour adds a line under
  `## [Unreleased]` in `CHANGELOG.md`, in one of the Keep a Changelog
  categories (Added, Changed, Deprecated, Removed, Fixed, Security). Label a
  pull request `skip-changelog` when there is genuinely nothing to tell users
  (CI-only changes, dependency locks).
- Commit messages: imperative subject ≤ 72 characters naming the concrete
  thing changed; a body that says *why* whenever the subject cannot.
- Keep pull requests to one logical change; CI must be green on both the
  x86_64 and arm64 builders and the two must produce identical assets.

## Cutting a release

Releases are cut by maintainers whose SSH key is in `allowed_signers`.
The version is decided by a human according to Semantic Versioning 2.0.0;
nothing infers it from commit messages.

```sh
nix run .#release -- prepare 1.2.0      # or: prepare minor
```

This rotates `[Unreleased]` into `## [1.2.0] - <today>`, commits
"Release v1.2.0" on a branch and opens a pull request. Once it is merged:

```sh
nix run .#release -- tag 1.2.0
```

This creates the signed, annotated tag `v1.2.0` (its message is the
changelog section), verifies it exactly as CI will, and pushes it. The push
of that tag is the only thing that triggers the release workflow, which
builds, attests, publishes and then verifies the release. Repositories that
allow direct pushes to `main` can do both steps at once with
`prepare 1.2.0 --direct`.

If the release workflow fails after the tag exists, the tag stays: a version
names a source snapshot, and a broken snapshot is fixed by the next version,
never by moving a tag.
