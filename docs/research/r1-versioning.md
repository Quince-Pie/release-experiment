<!-- Research digest produced for this repository on 2026-09-24 from primary sources only (specifications, official documentation, changelogs, official repositories). Quotes are verbatim; every source URL and its access date are listed at the end. Items the research could not verify are listed explicitly. -->

# Versioning schemes: primary-source findings

Research agent: r1-versioning. All sources accessed 2026-09-24. Live behaviour tests were run the same day on NixOS via `nix shell` (tool versions listed at the end). Quotes are verbatim from the cited page unless marked otherwise.

## Headline findings

1. **SemVer is still 2.0.0.** The semver/semver repo has no 3.0.0 branch, milestone or draft; every "3.0.0" ticket is closed. One substantive 2025 edit (FAQ "minor" changed to "patch") is in the repo but not yet published on semver.org.
2. **CalVer has no versioned spec.** calver.org is a terminology and case-study page dated July 1, 2019.
3. **Zero-padded CalVer splits the ecosystems.** `2026.09.24` and `26.09` are rejected by Go modules, Cargo, strict node-semver and Cabal. Python packaging, dpkg and Nix accept them and treat `09` as equal to `9`. Unpadded `2026.9.24` is valid SemVer syntax everywhere, but Go then requires the module path to end in `/v2026`, and Cargo and npm caret ranges treat each year as an incompatible major.
4. **GitHub's docs give three conflicting "Latest" rules.** The UI doc says semantic versioning, the REST get-latest doc says `created_at`, and `make_latest=legacy` says date then semver.
5. **Keep a Changelog 2.0.0 shipped 2026-06-07** (the site root still redirects to 1.1.0). Conventional Commits remains 1.0.0 with an unpublished "1.0.0-next" draft that changes the SemVer mapping for 0.y.z.

## 1. Semantic Versioning [S1–S6]

- **Current spec.** Page title "Semantic Versioning 2.0.0"; version links offered: 2.0.0, 2.0.0-rc.2, 2.0.0-rc.1, 1.0.0, 1.0.0-beta; no date shown on the page. Repo tags: v2.0.0, v1.0.0, v1.0.0-rc.1, v1.0.0-beta.
- **3.0.0 status** [S2, S3]. Default branch `master`; branches: master, docs/README, isaacs/ranges; milestones: none; 24 open PRs; last push 2025-11-05.
  - Issue #113 "branch for 3.0.0": opened 2013-06-12, closed 2018-10-10.
  - PR #682 "RFC proposal for semver 3.0.0 - LIBRARY version": opened 2021-03-26, closed unmerged 2021-12-05.
  - Issue #1010 "Semver 3.0.0: require opt-in": opened 2024-03-19, closed 2024-03-25.
  - Open PRs include "Bump version to 2.0.1 and Clarify build metadata rules", "feat: Add specification for SemVer Ranges", "[spec] document real-world v0 semantics", "Make notice about leading zeros clearer".
  - Conclusion: no 3.0.0 work is open as of 2026-09-24.
- **Leading zeros.** Rule 2: "A normal version number MUST take the form X.Y.Z where X, Y, and Z are non-negative integers, and MUST NOT contain leading zeroes." Rule 9: "Identifiers MUST comprise only ASCII alphanumerics and hyphens [0-9A-Za-z-]. Identifiers MUST NOT be empty. Numeric identifiers MUST NOT include leading zeroes. Pre-release versions have a lower precedence than the associated normal version."
- **Build metadata.** Rule 10: "Build metadata MAY be denoted by appending a plus sign and a series of dot separated identifiers immediately following the patch or pre-release version." Rule 11.1: "(Build metadata does not figure into precedence)."
- **Pre-release precedence.** Rule 11.4: "Identifiers consisting of only digits are compared numerically." / "Identifiers with letters or hyphens are compared lexically in ASCII sort order." / "Numeric identifiers always have lower precedence than non-numeric identifiers." / "A larger set of pre-release fields has a higher precedence than a smaller set, if all of the preceding identifiers are equal." Example: "1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0."
- **"v" prefix.** FAQ: "No, "v1.2.3" is not a semantic version. However, prefixing a semantic version with a "v" is a common way (in English) to indicate it is a version number." … "in which case "v1.2.3" is a tag name and the semantic version is "1.2.3"."
- **0.y.z.** Rule 4: "Major version zero (0.y.z) is for initial development. Anything MAY change at any time. The public API SHOULD NOT be considered stable." FAQ: "The simplest thing to do is start your initial development release at 0.1.0 and then increment the minor version for each subsequent release."
- **When to release 1.0.0.** FAQ: "If your software is being used in production, it should probably already be 1.0.0. If you have a stable API on which users have come to depend, you should be 1.0.0. If you're worrying a lot about backward compatibility, you should probably already be 1.0.0."
- **Accidental breaking change in a minor.** FAQ as live today: "As soon as you realize that you've broken the Semantic Versioning spec, fix the problem and release a new minor version that corrects the problem and restores backward compatibility. Even under this circumstance, it is unacceptable to modify versioned releases." Repo master (commit a57f5ce, 2025-06-16, PR #1128) changed this to "release a new patch version". The site source semver/semver.org (gh-pages `spec/v2.0.0.md`) still says "minor"; its nightly workflow only opens a PR titled "Original specification updates", so the fix is unpublished [S4, S5].
- **Public API.** Rule 1 is the only statement: "Software using Semantic Versioning MUST declare a public API. This API could be declared in the code itself or exist strictly in documentation. However it is done, it SHOULD be precise and comprehensive." No FAQ item covers software without a public API. Nearest: "Documenting the entire public API is too much work!" answered with "It is your responsibility as a professional developer to properly document software that is intended for use by others."
- **Breaking change shipped as a patch.** FAQ: "Use your best judgment. If you have a huge audience that will be drastically impacted by changing the behavior back to what the public API intended, then it may be best to perform a major version release".

## 2. CalVer [S7–S9]

- **No spec version** anywhere on the page; footer "July 1, 2019", "© 2020". Source repo github.com/mahmoud/calver: last commit 2025-06-30 ("ff note", attribution text only); previous 2024-05-28 "pytz -> IANA tzdb".
- **Framing.** "Rather than declaring a single scheme to be CalVer, it's important to recognize the practicality of each and design the scheme to fit the project."
- **Segments (verbatim).** "YYYY - Full year - 2006, 2016, 2106"; "YY - Short year - 6, 16, 106"; "0Y - Zero-padded year - 06, 16, 106"; "MM - Short month - 1, 2 ... 11, 12"; "0M - Zero-padded month - 01, 02 ... 11, 12"; "WW - Short week (since start of year) - 1, 2, 33, 52"; "0W - Zero-padded week - 01, 02, 33, 52"; "DD - Short day - 1, 2 ... 30, 31"; "0D - Zero-padded day - 01, 02 ... 30, 31". Non-date parts: Major, Minor, "Micro - The third and usually final number in the version. Sometimes referred to as the "patch" segment.", "Modifier - An optional text tag, such as "dev", "alpha", "beta", "rc1", and so on." Notes: "traditional, incremented version numbers are 0-based, whereas date segments are 1-based, and the short and zero-padded years are relative to the year 2000." "Convention suggests that four-numeric-segment versions are discouraged."
- **Projects (scheme strings as printed).** Ubuntu YY.0M.MICRO ("a short year and zero-padded month"); Twisted YY.MM.MICRO; youtube-dl YYYY.0M.0D; IANA/Olson tz database YYYYa..z; Teradata YY.MM.MINOR.MICRO ("The YY.MM part of the version are used as a combined SemVer major version"); boltons YY.MINOR.MICRO; certifi YYYY.MM.DD; fusefs-ntfs YYYY.MM.DD_MICRO; LibreOffice YY.MM; OpenSCAD YYYY.0M; pip YY.MINOR.MICRO; PyCharm YYYY.MINOR.MICRO; Stripe's API YYYY-MM-DD; Unity YYYY.MINOR.MICRO. Black, Microsoft Windows and pytz appear only on the separate Users page (schemes not extracted).
- **Guidance ("When to use CalVer").** "If both you and people you don't know use your project seriously, then use a serious version." Criteria: "Does your project feature a large or constantly-changing scope?" ("Large systems and frameworks, like Ubuntu and Twisted", "Amorphous sets of utilities, like Boltons") and "Is your project time-sensitive in any way? Do other external changes drive new project releases?" (business requirements, certifi security updates, "Political shifts, such as the IANA database's handling of timezone changes"). "If you answered yes to any of these questions, CalVer's semantics make it a strong choice for your project." Twisted rationale: "Twisted has a lot of parts, making SemVer a poor fit due to the individual parts deprecating and breaking compatibility individually."
- The page says nothing about zero-padding versus SemVer validity.

## 3. Compatibility matrix (tested 2026-09-24)

| Ecosystem (tool) | `2026.09.24` | `26.09` | `2026.9.24` | Ordering basis |
|---|---|---|---|---|
| Go (go1.26.7, x/mod v0.41.0) | invalid: "not a semantic version" | invalid | valid only if module path ends `/v2026` | SemVer 2.0.0, "v" required |
| Cargo 1.95.0 | "invalid leading zero in minor version number" | invalid | valid; default req = `>=2026.9.24, <2027.0.0` | SemVer, left-most non-zero |
| npm (node-semver 7.8.5, npm 11.17.0) | strict null; loose gives `2026.9.24` | invalid even loose | valid; `^` = `>=2026.9.24 <2027.0.0-0` | SemVer 2.0.0 |
| Python (packaging 26.1) | normalized to `2026.9.24`, equal | normalized to `26.9` | valid | integer tuple |
| dpkg 1.23.7 | eq `2026.9.24` | eq `26.9` | valid | digit/non-digit runs, `~` lowest |
| Nix 2.34.8 | compareVersions = 0 | 0 vs `26.9` | valid | numeric components; only "pre" sorts lower |
| Cabal 3.18 docs | "leading zero is not allowed" | invalid | valid (PVP major = 2026.9) | integer list |

### Go [S10, S11, S13]

- "Each version starts with the letter v, followed by a semantic version." "A canonical version starts with the letter v, followed by a semantic version following the Semantic Versioning 2.0.0 specification."
- x/mod/semver: "MAJOR, MINOR, and PATCH are decimal integers without extra leading zeros"; "This package follows Semantic Versioning 2.0.0 (see semver.org) with two exceptions. First, it requires the "v" prefix. Second, it recognizes vMAJOR and vMAJOR.MINOR (with no prerelease or build suffixes) as shorthands".
- Build metadata: "The build metadata suffix is ignored for the purpose of comparing versions. The go command accepts versions with build metadata and converts them to pseudo-versions to maintain the total ordering between versions."
- `+incompatible` "denotes a version released before migrating to modules version major version 2 or later"; "a tag like v4.1.2+incompatible will be ignored."
- Major suffix: "Starting with major version 2, module paths must have a major version suffix like /v2 that matches the major version."
- Pseudo-versions: "vX.0.0-yyyymmddhhmmss-abcdefabcdef is used when there is no known base version"; "vX.Y.Z-pre.0.yyyymmddhhmmss-abcdefabcdef is used when the base version is a pre-release"; "vX.Y.(Z+1)-0.yyyymmddhhmmss-abcdefabcdef is used when the base version is a release version"; "The timestamp must match the revision's timestamp."
- Retract: "A retract directive indicates that a version or range of versions of the module defined by go.mod should not be depended upon."
- Test: `module.Check("example.com/m","v2026.9.24")` returns "invalid version: should be v0 or v1, not v2026"; with path `example.com/m/v2026` it passes; `v0.2026.0924` is "not a semantic version". A YYYY-major CalVer therefore forces a new import path every year.

### Cargo [S14–S16]

- "The version field is formatted according to the SemVer specification: Versions must have three numeric parts, the major version, the minor version, and the patch version."
- "Versions are considered compatible if their left-most non-zero major/minor/patch component is the same. This is different from SemVer which considers all pre-1.0.0 packages to be incompatible." Expansions: "1.2.3 := >=1.2.3, <2.0.0", "0.2.3 := >=0.2.3, <0.3.0", "0.0.3 := >=0.0.3, <0.0.4", "0 := >=0.0.0, <1.0.0".
- semver.html: "Initial development releases starting with "0.y.z" can treat changes in "y" as a major release, and "z" as a minor release. "0.0.z" releases are always major changes."
- "Version metadata, such as 1.0.0+21AF26D3, is ignored and should not be used in version requirements."
- Cargo also rejects `2026.9` ("unexpected end of input while parsing minor version number").

### npm [S17, S18]

- package.json docs: "Version must be parseable by node-semver, which is bundled with npm as a dependency."
- README: "A leading "=" or "v" character is stripped off and ignored. Support for stripping a leading "v" is kept for compatibility with v1.0.0 of the SemVer specification but should not be used anymore."
- "Prerelease identifiers (pre) use nr for numeric parts, which disallows leading zeros (e.g., 1.2.3-00 is invalid). Build metadata identifiers (build) allow any alphanumeric string including leading zeros".
- Caret: "Allows changes that do not modify the left-most non-zero element in the [major, minor, patch] tuple." ("^0.2.3 := >=0.2.3 <0.3.0-0").
- loose: "Be more forgiving about not-quite-valid semver strings. (Any resulting output will always be 100% strict compliant, of course.)"
- Tests: `npm version 2026.09.25` rewrote package.json to `2026.9.25`; `npm pack --dry-run` accepted `2026.09.24` unchanged; `compare("2026.9.24+build.1","2026.9.24")` = 0.

### Python [S19, S20]

- PEP 440 banner: "This PEP is a historical document. The up-to-date, canonical spec, Version specifiers, is maintained on the PyPA specs page."
- Scheme `[N!]N(.N)*[{a|b|rc}N][.postN][.devN][+local]`.
- Integer normalization: "an integer version of 00 would normalize to 0 while 09000 would normalize to 9000."
- v prefix: "versions may be preceded by a single literal v character. This character MUST be ignored for all purposes".
- Ordering: "Comparison and ordering of release segments considers the numeric value of each component of the release segment in turn. When comparing release segments with different numbers of components, the shorter segment is padded out with additional zeros".
- "Date-based release segments are also permitted." (example 2012.4, 2012.7, 2012.10, 2013.1).
- Local versions: digit segments compare as integers, letter segments are "compared lexicographically with case insensitivity", and "the numeric section always compares as greater than the lexicographic segment"; a local version sorts above the same public version (tested).
- Epoch note added Jan 2026: "Use of nonzero epochs is discouraged. They are often not supported or discouraged by downstream packaging" and "it is preferable to continue with monotonically increasing numbers in epoch zero. For example, the version 2026.x could be unambiguously followed by 3000.x."

### Debian [S21]

- Format "[epoch:]upstream-version[-debian-revision]"; upstream-version "may contain only alphanumerics ("A-Za-z0-9") and the characters . + - : ~ ... and should start with a digit."
- Sorting: "The strings are compared from left to right. First the initial part of each string consisting entirely of non-digit characters is determined." "The lexical comparison is a comparison of ASCII values modified so that all the letters sort earlier than all the non-letters and so that a tilde sorts before anything, even the end of a part." "Then the initial part of the remainder of each string which consists entirely of digit characters is determined. The numerical values of these two parts are compared". "an empty string ... counts as zero."
- Tests: `2026.09.24` eq `2026.9.24`; `2026.09.24~rc1` lt release; `2026.09.24+build1` gt release; `1:2.0` gt `2026.09.24`. Man page: dpkg 1.23.11, dated 2026-09-09.

### Nix [S22–S24]

- builtins.compareVersions: "return -1 if version s1 is older than version s2, 0 if they are the same, and 1 if s1 is newer than s2."
- nix-env algorithm: "The versions are compared by splitting them into contiguous components of numbers and letters." "If they are both numbers, integer comparison is used. If a is an empty string and b is a number, a is considered less than b." "The special string component pre (for pre-release) is considered to be less than other components. String components are considered less than number components."
- nixpkgs: `versionOlder = v1: v2: compareVersions v2 v1 == 1;` and `versionAtLeast = v1: v2: compareVersions v2 v1 != 1;`.
- Tests: `2026.09.24` vs `2026.9.24` = 0; `2026.09.24-rc1` vs `2026.09.24` = 1, so an rc suffix sorts newer than the release and only "pre" sorts older; `2026.09.24pre1` = -1; `v2026.09.24` sorts below `2026.09.24` because "v" becomes a string component.

### Haskell PVP [S25–S27]

- "A package version number SHOULD have the form A.B.C, and MAY optionally have any number of additional components, for example 2.1.0.4". "A.B is known as the major version number, and C the minor version number."
- FAQ: "the PVP doesn't distinguish between 0.x.y and 1.x.y"; on tags and metadata: "the PVP does not regulate nor support such additional information in version numbers."
- Cabal 3.18.1.0 field reference: "Version is to first approximation numbers separated by dots, where leading zero is not allowed and each version digit is consists at most of nine characters."

## 4. GitHub "Latest" [S28–S32]

- UI doc: "Optionally, select Set as latest release. If you do not select this option, the latest release label will automatically be assigned based on semantic versioning."
- REST "Get the latest release": "The latest release is the most recent non-prerelease, non-draft release, sorted by the created_at attribute. The created_at attribute is the date of the commit used for the release, and not the date when the release was drafted or published."
- REST `make_latest`: "Drafts and prereleases cannot be set as latest. Defaults to true for newly published releases. legacy specifies that the latest release should be determined based on the release creation date and higher semantic version."
- Changelog 2022-10-21 "Explicitly Set the Latest Release": "Previously, a repository's latest release was the one created on the most recent date. In the event that multiple releases had the same date, the semantic version number broke the tie." "This new feature provides an explicit toggle to mark a release "latest" when you create it."
- Linking doc only defines the `/releases/latest` URL; no rule.
- Immutable releases (preview 2025-08-26, GA 2025-10-28): "Once you publish a release as immutable, its assets can't be added, modified, or deleted." "Tags for new immutable releases are protected and can't be deleted or moved." Docs: "You can still edit the title and release notes, and change whether the release is a pre-release or the latest release."
- The three descriptions conflict, and the docs do not say which governs the badge.

## 5. Other schemes

- **EffVer** [S33], page dated Jan 15, 2024: "Intended Effort Versioning (EffVer for short)". Macro: "you will need to dedicate some significant time to upgrading to this version"; Meso: "some small effort may be required to make sure this version works for you"; Micro: "this change doesn't intend for you to need to do anything". "is forward and backward compatible with SemVer (you don't need to use something like a Python version epoch to switch between the two schemes)". Zero versions "should be treated as 0.Macro.Micro". Critique: "the trap that SemVer falls into is the fact that every bug has users".
- **BreakVer** [S34]: "<major>.<minor>.<non-breaking>[-<optional-qualifier>]"; "<major> - Major breaking changes [or discretionary "major non-breaking changes"]"; "<minor> - Minor breaking changes [or discretionary "minor non-breaking changes"]"; "<non-breaking> - Strictly NO breaking changes, ever (!!)". Test: "Is it possible that your change (bug fix, new feature, whatever) could break anyone's code?" "If yes: bump one of <major> or <minor> (your choice). A <non-breaking> bump is strictly disallowed!" Author and date are not stated on the page.
- **ZeroVer** [S35, S36]: "Your software's major version should never exceed the first and most important number in computing: zero." "NO: 1.0, 1.0.0-rc1, 18.0, 2018.04.01". Page dated "April 1, 2018"; About page: "ZeroVer is satire. Seriously, don't actually use it." The project table is still updated, with 2026 entries such as FastAPI 0.141.1 and Neovim 0.12.5.
- **Semantic Import Versioning** [S10, S13, S37]: go.dev/ref/mod: "Major version suffixes implement the import compatibility rule: If an old package and a new package have the same import path, the new package must be backwards compatible with the old package." Origin: Russ Cox, "Semantic Import Versioning (Go & Versioning, Part 3)" on research.swtch.com (author's page).
- **Ubuntu** [S38]: "Ubuntu releases a new version every six months. Releases of Ubuntu get a development codename ('Resolute Raccoon') and are versioned by the year and month of delivery - for example, Ubuntu 26.04 was released in April 2026." "LTS are released every two years and receive 5 years of standard security maintenance."

## 6. Keep a Changelog and Conventional Commits

### Keep a Changelog [S39–S41]

- keepachangelog.com meta-refreshes to `/en/1.1.0/`, but `/en/2.0.0/` is live with "## [2.0.0] - 2026-06-07": "2.0.0 is the first major revision of Keep a Changelog. It breaks the guidance, not the format: the six change types, YYYY-MM-DD dates, and the Unreleased and [YANKED] markers are all unchanged". Repo commits continue to 2026-09-03; git tags stop at v1.1.2.
- 1.1.0 rules: "There should be an entry for every single version." "The latest version comes first." "Mention whether you follow Semantic Versioning." Types: "Added for new features. Changed for changes in existing functionality. Deprecated for soon-to-be removed features. Removed for now removed features. Fixed for any bug fixes. Security in case of vulnerabilities." "Keep an Unreleased section at the top to track upcoming changes." Dates ISO 8601 (2017-07-17 style). Yanked: "## [0.0.5] - 2014-12-13 [YANKED]", "The [YANKED] tag is loud for a reason." Links: "[unreleased]: https://github.com/olivierlacan/keep-a-changelog/compare/v1.1.2...HEAD". "Call it CHANGELOG.md."
- 2.0.0 adds: "Use the YYYY-MM-DD format."; reference links "[Unreleased]: https://github.com/your/project/compare/v1.1.0...HEAD" with the oldest version as "[1.0.0]: https://github.com/your/project/releases/tag/v1.0.0"; "You do not have to use Semantic Versioning. Calendar versioning, a plain number, or a date all work; note which scheme you use"; "Add a short **Breaking:** marker"; "There are only six types on purpose."; "Dependencies are not a type of change."; "A yanked release is a version pulled because of a serious bug or security issue. List it; do not hide it."

### Conventional Commits [S42–S44]

- Site root redirects to `/en/v1.0.0/`, page "Conventional Commits 1.0.0"; repo has no tags; the version menu lists only v1.0.0 and v1.0.0-beta through beta.4.
- Summary: "fix ... (this correlates with PATCH in Semantic Versioning)"; "feat ... (this correlates with MINOR in Semantic Versioning)"; "BREAKING CHANGE: a commit that has a footer BREAKING CHANGE:, or appends a ! after the type/scope, introduces a breaking API change (correlating with MAJOR".
- Spec: "Breaking changes MUST be indicated in the type/scope prefix of a commit, or as an entry in the footer." "If included in the type/scope prefix, breaking changes MUST be indicated by a ! immediately before the :. If ! is used, BREAKING CHANGE: MAY be omitted from the footer section". "with the exception of BREAKING CHANGE which MUST be uppercase." "BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE, when used as a token in a footer."
- FAQ: "Commits with BREAKING CHANGE in the commits, regardless of type, should be translated to MAJOR releases."
- Draft: `content/next/index.md` has `draft: true` and "# Conventional Commits 1.0.0-next"; `/en/next/` returns 404. It rewrites the mapping to "correlating with MAJOR when the version >= 1.0.0, and MINOR when on a pre-release 0.y.z version" and adds an "INITIAL STABLE RELEASE:" footer or "!!" "denoting the promotion from a pre-release version 0.y.z to 1.0.0" (commit 2024-03-27 "feat!: support promoting pre-release versions to 1.0 (#561)"; last touched 2026-03-11).

## 7. 2025–2026 changes

- **SemVer**: 2025-06-16 FAQ fix minor to patch (repo only, unpublished on the site); 2025-06-23 style fixes; 2025-11-05 citation metadata. Spec number unchanged.
- **Python** spec History: "May 2025: Clarify that development releases are a form of pre-release when they are handled." "Nov 2025: Make arbitrary equality case insensitivity explicit." "Jan 2026: The use of epochs was discouraged." No new versioning PEP found.
- **Go** [S45–S47]: 1.24 (2025-02-11): "A +dirty suffix will be appended if there are uncommitted changes."; 1.25 (2025-08-12): "The new go.mod ignore directive can be used to specify directories the go command should ignore."; 1.26 (2026-02-10): "go mod init now defaults to a lower go version in new go.mod files."
- **Cargo** changelog [S48]: 1.84 (2025-01-09) "Stabilize resolver v3, a.k.a the MSRV-aware dependency resolver."; 1.87 (2025-05-15) "Mention x.y.* as a kind of version requirement to avoid."; 1.92 (2025-12-11) "Clarify multiple version requirement behavior" and "SemVer: Recommend package.rust-version in the Rust version section".
- **calver.org**: only an attribution edit (2025-06-30); no scheme changes.
- **GitHub**: immutable releases preview 2025-08-26, GA 2025-10-28.
- **Keep a Changelog** 2.0.0 released 2026-06-07. **Conventional Commits**: draft only.

## Could not verify

- npm registry-side acceptance of `2026.09.24` at publish time (local CLI only).
- Whether semver.org will merge the June 2025 FAQ change. Bot PRs titled "Original specification updates" exist in semver/semver.org, but their state was unreadable after the GitHub API rate limit hit.
- Which of GitHub's three "latest" rules governs the badge in practice.
- CalVer Users-page schemes for Black, Windows, pytz.
- Cabal parsing (docs only, no compiler run); Go tested via the x/mod library, not a live proxy fetch.
- EffVer adopter list came from a summarizer pass, not verbatim text.
- BreakVer authorship and date (absent from the page).

## Sources (all accessed 2026-09-24)

- S1 https://semver.org/spec/v2.0.0.html
- S2 https://api.github.com/repos/semver/semver (plus /branches, /milestones, /tags, /commits)
- S3 https://github.com/semver/semver/issues/113 ; https://github.com/semver/semver/pull/682 ; https://github.com/semver/semver/issues/1010 ; https://github.com/semver/semver/pull/1128
- S4 https://github.com/semver/semver (git clone; semver.md commit a57f5ce, 2025-06-16)
- S5 https://raw.githubusercontent.com/semver/semver.org/gh-pages/spec/v2.0.0.md and https://raw.githubusercontent.com/semver/semver.org/gh-pages/.github/workflows/sync.yml
- S6 https://github.com/semver/semver/blob/master/README.md
- S7 https://calver.org/
- S8 https://calver.org/users.html
- S9 https://github.com/mahmoud/calver (git log)
- S10 https://go.dev/ref/mod
- S11 https://pkg.go.dev/golang.org/x/mod/semver
- S12 https://go.dev/doc/modules/version-numbers
- S13 https://go.dev/blog/v2-go-modules
- S14 https://doc.rust-lang.org/cargo/reference/manifest.html
- S15 https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html
- S16 https://doc.rust-lang.org/cargo/reference/semver.html
- S17 https://github.com/npm/node-semver (README, main branch)
- S18 https://docs.npmjs.com/cli/v11/configuring-npm/package-json
- S19 https://peps.python.org/pep-0440/
- S20 https://packaging.python.org/en/latest/specifications/version-specifiers/
- S21 https://manpages.debian.org/unstable/dpkg-dev/deb-version.7.en.html
- S22 https://nix.dev/manual/nix/latest/language/builtins.html
- S23 https://nix.dev/manual/nix/latest/command-ref/nix-env/upgrade.html
- S24 https://github.com/NixOS/nixpkgs/blob/master/lib/strings.nix
- S25 https://pvp.haskell.org/
- S26 https://pvp.haskell.org/faq/
- S27 https://cabal.readthedocs.io/en/stable/buildinfo-fields-reference.html
- S28 https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
- S29 https://docs.github.com/en/rest/releases/releases
- S30 https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases
- S31 https://github.blog/changelog/2022-10-21-explicitly-set-the-latest-release/
- S32 https://github.blog/changelog/2025-10-28-immutable-releases-are-now-generally-available/ and https://github.blog/changelog/2025-08-26-releases-now-support-immutability-in-public-preview/
- S33 https://jacobtomlinson.dev/effver/
- S34 https://www.taoensso.com/break-versioning
- S35 https://0ver.org/
- S36 https://0ver.org/about.html
- S37 https://research.swtch.com/vgo-import (author's page)
- S38 https://ubuntu.com/about/release-cycle
- S39 https://keepachangelog.com/en/1.1.0/
- S40 https://keepachangelog.com/en/2.0.0/
- S41 https://github.com/olivierlacan/keep-a-changelog (tags, commits)
- S42 https://www.conventionalcommits.org/en/v1.0.0/
- S43 https://github.com/conventional-commits/conventionalcommits.org (content/next/index.md, git log)
- S44 https://www.conventionalcommits.org/en/ (redirect target)
- S45 https://go.dev/doc/go1.24 ; S46 https://go.dev/doc/go1.25 ; S47 https://go.dev/doc/go1.26 (release dates from https://go.dev/doc/devel/release)
- S48 https://doc.rust-lang.org/cargo/CHANGELOG.html

## Test environment

NixOS with Nix 2.34.8. Other tools obtained via `nix shell`: go1.26.7 with golang.org/x/mod v0.41.0, cargo 1.95.0, node v24.19.0 with semver 7.8.5 and npm 11.17.0, Python 3.13.15 with packaging 26.1, dpkg 1.23.7. Raw page captures, git clones and test scripts are in `/tmp/claude-1000/-tmp-release-experiment/b6dd3ee4-f98f-46e1-b2e4-780cd93d4ed7/scratchpad/`.
