# 0001. Versioning: Semantic Versioning 2.0.0, released as tags `vX.Y.Z`

Status: accepted (2026-09-24). Research: [`docs/research/r1-versioning.md`](../research/r1-versioning.md)
(specifications and consumer grammars, with live tests of Go, Cargo, npm, Python packaging, dpkg, Nix and Cabal on 2026-09-24).

## The question

Which versioning scheme, and which version of that scheme, should a release
use: Semantic Versioning, Calendar Versioning, or one of the newer
proposals. "Which version" has a short factual answer and the scheme itself
has a reasoned one.

## Facts that bound the decision

- **Semantic Versioning is at 2.0.0 and there is no 3.0.0.** The spec's
  repository has no 3.0.0 branch, milestone or draft; every 3.0.0 ticket is
  closed (issue #113 in 2018, PR #682 unmerged in 2021, issue #1010 in
  2024). The only substantive 2025 edit corrects one FAQ answer from "new
  minor version" to "new patch version" and is not yet published on
  semver.org. So the choice of version is 2.0.0.
- **CalVer has no versioned specification.** calver.org is a terminology
  and case-study page dated 2019-07-01 whose framing is "rather than
  declaring a single scheme to be CalVer, it's important to recognize the
  practicality of each and design the scheme to fit the project". "Which
  version of CalVer" therefore means "which format", e.g. `YYYY.0M.0D`
  (youtube-dl), `YY.0M.MICRO` (Ubuntu), `YYYY.MINOR.MICRO` (PyCharm, Unity).
- **Zero-padded CalVer is not a valid version in the ecosystems that
  resolve versions.** Tested: `2026.09.24` and `26.09` are rejected by Go
  modules ("not a semantic version"), Cargo ("invalid leading zero"),
  strict node-semver and Cabal; Python packaging, dpkg and Nix accept them
  and normalise `09` to `9`. SemVer 2.0.0 item 2: "MUST NOT contain leading
  zeroes."
- **Unpadded CalVer is valid SemVer *syntax* but wrong SemVer
  *semantics*.** `2026.9.24` parses everywhere, but Go then requires the
  module path to end in `/v2026` and a new import path every year
  (`module.Check` returns "should be v0 or v1, not v2026"), and Cargo and
  npm caret ranges treat every new year as an incompatible major release.
- **Nix orders suffixes differently from SemVer.** `builtins.compareVersions
  "2026.09.24-rc1" "2026.09.24"` returns 1 (the release candidate sorts
  *newer*); only the literal component `pre` sorts older. Pre-release
  suffixes in a Nix `version` attribute therefore need care; nixpkgs'
  convention for unreleased snapshots is `<last>-unstable-YYYY-MM-DD`.
- **GitHub's "latest release" is described three different ways** in its
  own documentation (semantic version in the UI docs, `created_at` in the
  REST "get latest" docs, "creation date and higher semantic version" for
  `make_latest=legacy`). The only deterministic behaviour is to set
  `make_latest` explicitly.
- Keep a Changelog 2.0.0 (2026-06-07) keeps the 1.1.0 format and says "You
  do not have to use Semantic Versioning. Calendar versioning, a plain
  number, or a date all work; note which scheme you use." Conventional
  Commits is at 1.0.0, and its unpublished `1.0.0-next` draft changes how a
  breaking change maps to a version on `0.y.z`.

## The selection rule

A version string is read by two audiences. Machines (Go modules, Cargo,
npm, Nix, Debian, GitHub's release list, Dependabot) need to *parse* it and
*order* it, and many of them also need a *compatibility signal* to resolve
ranges. Humans need to know *whether upgrading will break something* and
*how old a release is*. The scheme should carry the information that
cannot be obtained elsewhere and omit what can.

- *When* a release was made is already recorded three times: the tag's
  date, the release's date and the changelog heading's date. Putting it in
  the version string adds nothing a consumer cannot see.
- *Whether* a release is compatible with the previous one is not recorded
  anywhere else. Only the version can carry it, and only SemVer-style
  schemes do.

So a scheme that encodes time instead of compatibility discards the one
piece of information the version string is uniquely placed to carry.

## Candidates

| Scheme | What the number encodes | Consumer compatibility | Verdict |
| --- | --- | --- | --- |
| **SemVer 2.0.0** (`MAJOR.MINOR.PATCH[-pre][+build]`) | Compatibility contract, decided by a human | Native in Go, Cargo, npm, Cabal; parseable by Python, dpkg, Nix | **Adopted** |
| CalVer `YYYY.0M.0D`, `YY.0M` (Ubuntu, youtube-dl) | Date | Invalid in Go, Cargo, npm, Cabal | Rejected |
| CalVer `YYYY.MM.DD`, `YYYY.MINOR.MICRO` (unpadded) | Date (and an arbitrary counter) | Parses, but Go demands a yearly import-path change and range resolvers treat each year as breaking | Rejected for anything with a resolver; acceptable for end-user applications with no dependency consumers and time-driven releases (calver.org's own criteria: "large or constantly-changing scope", "time-sensitive" such as the tz database or certifi) |
| EffVer (Intended Effort Versioning, 2024) | Expected upgrade effort (macro/meso/micro) | Same syntax as SemVer, "forward and backward compatible with SemVer" | A *policy* for choosing the number, not a different format; its "effort" criterion is subjective where SemVer's "backwards compatible" is checkable. Not adopted, compatible with the tooling here |
| BreakVer | Breaking in both major and minor; third number never breaks | SemVer syntax | Same objection; its extra strictness on the third number is a policy this project already follows |
| PVP (Haskell) | `A.B` major, `C` minor | Cabal only | Ecosystem-specific |
| ZeroVer | Nothing (major stays 0) | – | Satire, explicitly ("Seriously, don't actually use it"); its serious content is SemVer item 4, which is applied below |

## Decision

- **Semantic Versioning 2.0.0**, applied literally. `relver` implements the
  specification's own regular expression and precedence rules and is tested
  against the ordered example in item 11; the changelog lint and the tag
  check use it, so an invalid or misordered version cannot reach a tag.
- **Tags are `vX.Y.Z`**. The `v` is a tag-name convention, not part of the
  version (SemVer FAQ: "v1.2.3" is a tag name and the semantic version is
  "1.2.3"); Go modules require it, and GitHub's documentation, Dependabot
  and most tooling assume it. Build metadata (`+…`) never appears in tags
  (Go ignores it; Nix does not order it as SemVer does).
- **Initial development is `0.y.z`, starting at `0.1.0`** (SemVer FAQ), and
  `1.0.0` is declared when the command-line interface is a stable public
  API "on which users have come to depend". Under `0.y.z` a breaking change
  bumps the minor version, matching Cargo's and Conventional Commits'
  `next` reading of the specification.
- **The compatibility judgement is made by a person** reading the change,
  assisted where a public API exists by API-diff tooling (`gorelease`
  or `apidiff` for Go, `cargo-semver-checks` for Rust, `japicmp` for Java).
  It is not inferred from commit-message prefixes: Conventional Commits is a
  message convention whose mapping to versions is a heuristic (its own
  next draft rewrites the mapping), and a mislabelled commit would silently
  produce a wrong version.
- **Development snapshots use Go's pseudo-version form** (`X.Y.(Z+1)-0.
  <timestamp>-<rev>`, see [0002](0002-changelog-as-version-source.md)),
  which is valid SemVer and orders correctly in every consumer listed
  above, and is what `nix build` reports on any untagged commit.
- **GitHub's "latest" flag is set explicitly** by comparing the new version
  with every published non-pre-release version, so a patch release of an
  older line never becomes "latest".

## When the answer would differ

An application with no dependency consumers, whose releases are driven by
external events (a timezone database, a certificate bundle, a distribution
snapshot), gains a little legibility from CalVer and loses nothing, as long
as the format is unpadded or is never fed to a SemVer resolver. A library,
a module, a CLI that others script against, or anything published to a
registry that resolves ranges should use SemVer 2.0.0, and can add a date
to release notes if age matters to its users.

## Sources

Semantic Versioning 2.0.0: https://semver.org/spec/v2.0.0.html and the
semver/semver repository (issues #113, #1010, PR #682, PR #1128).
CalVer: https://calver.org/ and https://calver.org/users.html.
Go: https://go.dev/ref/mod (versions, pseudo-versions, major version
suffixes); https://pkg.go.dev/golang.org/x/mod/semver. Cargo:
https://doc.rust-lang.org/cargo/reference/semver.html and
specifying-dependencies.html. npm: https://github.com/npm/node-semver.
Python: https://packaging.python.org/en/latest/specifications/version-specifiers/.
Debian: deb-version(7). Nix: https://nix.dev/manual/nix/latest/language/builtins.html
(`compareVersions`) and nixpkgs `pkgs/README.md` (versioning). GitHub:
https://docs.github.com/en/rest/releases/releases (`make_latest`), the
2022-10-21 changelog "Explicitly set the latest release". Keep a Changelog
2.0.0: https://keepachangelog.com/en/2.0.0/. Conventional Commits 1.0.0:
https://www.conventionalcommits.org/en/v1.0.0/. EffVer:
https://jacobtomlinson.dev/effver/. BreakVer:
https://www.taoensso.com/break-versioning. ZeroVer: https://0ver.org/about.html.
All accessed 2026-09-24; full quotes in the research digest.
