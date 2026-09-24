<!-- Research digest produced for this repository on 2026-09-24 from primary sources only (specifications, official documentation, changelogs, official repositories). Quotes are verbatim; every source URL and its access date are listed at the end. Items the research could not verify are listed explicitly. -->

# Release-tooling vetting report (r5-tools)

Status: FINAL (complete). All sources accessed 2026-09-24. Repository metadata is from the GitHub REST API (`/repos/<owner>/<repo>` and `/releases/latest`) fetched 2026-09-24T05:24Z; raw output saved at `/tmp/claude-1000/-tmp-release-experiment/b6dd3ee4-f98f-46e1-b2e4-780cd93d4ed7/scratchpad/meta.out`. Every quote is verbatim from the tool's own docs/README or from GitHub Docs. `[n]` refers to the numbered source list at the end.

## 1. Summary table

| Tool | Latest / date | Archived? | Trigger | Versioning | Scope | Token needs | Signing / SBOM / attestation | Notes |
|---|---|---|---|---|---|---|---|---|
| release-please (+action) | v17.11.2, 2026-08-24; action v5.0.0, 2026-04-22 | No; pushed 2026-09-14 / 2026-08-28 | Release PR; merge creates tag + GH release | Conventional Commits; `Release-As` override; no CalVer found | 20+ strategies, manifest monorepo, `simple`/generic | GITHUB_TOKEN works but its tags/PRs/releases trigger nothing; PAT or App token advised | None | Squash-merge "highly" recommended; README still shows `@v4`, v5 = Node 24 |
| semantic-release | v25.0.9, 2026-08-05 | No; pushed 2026-09-22 | Branch push in CI, no PR | Angular/Conventional commit analysis | Node CLI, "any type of packages" via plugins; no monorepo FAQ | GITHUB_TOKEN "cannot be used if branch protection is enabled"; PATs discouraged | npm provenance via OIDC | Docs moved to semantic-release.org; 0.x start unsupported |
| changesets (+action) | cli 3.0.3, 2026-09-14; action v2.1.2, 2026-09-07 | No | "Version Packages" PR, publish on merge | Explicit intent files (patch/minor/major) | pnpm/yarn/npm workspaces | contents+pull-requests write; id-token for trusted publishing | API-mode commits/tags "signed using GitHub's GPG key"; npm trusted publishing | Prereleases "very complicated" |
| git-cliff (+action) | v2.14.2, 2026-09-18; action `@v4` | No; pushed 2026-09-18 | Local CLI / action; changelog only | `--bump` from conventional commits; `[bump]` rules; no CalVer | Language-agnostic; `--include-path` monorepo | Optional token only for GitHub integration/rate limits | None | Does not create tags/releases (not a documented feature) |
| GoReleaser v2 (+action) | v2.18.2, 2026-09-17; action v7.2.3, 2026-06-29 | No; pushed 2026-09-21 | Tag push (`goreleaser release`) | Explicit git tag; nightly = Pro | Go, Rust, Zig, Bun, Deno, uv/Poetry builders OSS; Python "Coming soon"; monorepo Pro | GITHUB_TOKEN same-repo; PAT for tap/bucket; GitLab/Gitea tokens | GPG/cosign signing, syft SBOM, checksums, attest example; DMG/notarize Pro | Draft->upload->publish always; v2.18 immutable-release preflight |
| release-plz | 0.3.169, 2026-09-19 | No; pushed 2026-09-24 | Release PR + `release` job | Conventional commits + cargo-semver-checks | Rust/Cargo workspaces; GitHub/GitLab/Gitea | "default GITHUB_TOKEN cannot trigger other workflow runs"; PAT or App | None found | git-cliff changelog, Keep a Changelog default |
| cargo-release | v1.1.6, 2026-09-16 | No; pushed 2026-09-18 | Local CLI, dry-run default | Explicit level/version | Rust workspaces | Local git/crates.io creds | GPG `sign-tag`/`sign-commit` | No changelog generation |
| knope (+action) | knope/v0.23.0, 2026-05-24 | No; pushed 2026-09-23 | Release PR or workflow_dispatch; `knope release` | Conventional commits and/or changesets | Cargo, npm, deno, pyproject, go.mod, gleam, pom, pubspec, tauri; GitHub + Gitea | Recipes use `secrets.PAT` fine-grained contents RW | None | Draft->assets->publish; 191 stars |
| cocogitto | 7.0.0, 2026-03-04 | No; pushed 2026-04-22 | Local CLI / action, tag via hooks | `cog bump --auto`; never auto-bumps to 1.0.0 | Language-agnostic; monorepo `[packages]` | Not documented | Not documented | 5 months since last push |
| commitizen | v4.19.0, 2026-09-22 | No; pushed 2026-09-22 | Local CLI / action, commit+tag pushed | Conventional commits; pep440/semver/semver2 | Providers: pep621, poetry, uv, cargo, npm, composer, scm | PAT required to trigger downstream ("treated like [skip ci]") | `--gpg-sign`, annotated tags | Keep a Changelog output |
| python-semantic-release | v10.7.0, 2026-09-22 | No; pushed 2026-09-22 | Branch push action; version+tag+release | Parsers angular/conventional/emoji/scipy/tag | Python-centric; GitHub/GitLab/Gitea/Bitbucket; monorepo parser v10.4+ | GH_TOKEN; branch protection needs PAT; `concurrency` advised | SSH commit/tag signing inputs | `root_options` removed (command injection) |
| towncrier | 26.9.0, 2026-09-04 | No; pushed 2026-09-08 | Local CLI (`build`) | No versioning; fragments | Any project ("usable with any project type") | None | None | Keep a Changelog Markdown template |
| softprops/action-gh-release | v3.0.3, 2026-08-30 | No; pushed 2026-09-21 | Any workflow; typically tag push | Tag given/`github.ref_name` | Agnostic | `contents: write` | None; immutable-aware | v2 unmaintained; v3 Node 24 |
| ncipollo/release-action | v1.21.0, 2026-03-14 | No; pushed 2026-09-10 | Any workflow | Tag from ref or input | Agnostic | `contents: write` | `immutableCreate` draft->upload->publish | |
| release-drafter | v7.7.0, 2026-07-29 | No; pushed 2026-09-23 | Push to branch drafts; publish manual or `publish: true` | Labels -> semver increment | Agnostic, PR-based | GITHUB_TOKEN; `contents: write` (+PR write for autolabeler) | None | Notes from PRs only |
| cargo-dist / dist | v0.33.0, 2026-09-10 | No; pushed 2026-09-24 | Tag push or workflow_dispatch (`dispatch-releases`) | Explicit tag | Cargo, npm, generic `build-command` | GITHUB_TOKEN; `GH_RELEASES_TOKEN` for external repo; tap token | GitHub attestations, checksums, cargo-auditable, CycloneDX, OmniBOR, Windows/macOS signing; Sigstore "coming soon" | Axo Releases removed 0.29.0; docs on GitHub Pages |
| svu | v3.4.1, 2026-05-01 | No; pushed 2026-09-01 | Local CLI prints version | Conventional commits | Agnostic | None | None | No tag creation |
| conventional-changelog / standard-version | template-v1.4.0, 2026-08-18; std-version v9.5.0, 2022-05-15 | No (std-version deprecated) | Node libs/CLI | Conventional commits | Node LTS only | n/a | None | standard-version "deprecated" -> release-please |
| taiki-e create-gh-release / upload-rust-binary | v1.11.0 / v1.30.2, 2026-04-17 | No; pushed 2026-09-01/02 | Tag push | Tag; Keep a Changelog parse | Rust binaries | `contents: write`, `github.token` | Checksums sha256/512/b2/sha1/md5; macOS codesign | Release created before upload |
| mikepenz/release-changelog-builder | v6.3.0, 2026-08-28 | No; pushed 2026-09-08 | Any workflow | n/a (notes only) | GitHub, Gitea | Read-only contents + PRs | None | PR/COMMIT/HYBRID modes |
| actions/create-release, upload-release-asset | v1.1.4 (2020-09-14); v1.0.2 (2020-02-10) | YES, both; pushed 2021-03-03 | Tag push | n/a | n/a | GITHUB_TOKEN | None | "currently unmaintained" |
| gh CLI (`gh release create`) | v2.101.0, 2026-09-15 | No | CLI | n/a | n/a | gh auth | `gh release verify`, `verify-asset` | Draft->upload->publish sequence documented |
| Renovate | 44.111.4, 2026-09-23 | No | App/self-hosted | n/a | nix manager beta, off by default | PAT needs `workflow` scope for workflow files | Digest pinning with version comment | `lockFileMaintenance` off by default |
| Dependabot | core v0.397.0, 2026-09-21 | No | GitHub-native | n/a | github-actions, nix (2026-04-07) | n/a | SHA + comment updates | cooldown: github-actions default-days only |
| DeterminateSystems update-flake-lock / flake-checker-action | v29 / v14, 2026-09-09 | No; pushed 2026-09-20 / 09-16 | schedule/workflow_dispatch | n/a | Nix flakes | PAT to run CI on PR; checker needs none | GPG-signed commits option | Checker telemetry on by default |

## 2. General failure modes (GitHub Docs)

- GITHUB_TOKEN triggering: "When you use the repository's `GITHUB_TOKEN` to perform tasks, events triggered by the `GITHUB_TOKEN` will not create a new workflow run, with the following exceptions: `workflow_dispatch` and `repository_dispatch` events always create workflow runs." [1] PR exception: `pull_request` opened/synchronize/reopened "create workflow runs in an approval-required state". Fix: "use a GitHub App installation access token or a personal access token instead of `GITHUB_TOKEN`". [2]
- Consequence: release-PR tools need an elevated token twice (CI on the PR, and downstream workflows after the tag/release). Tag-push tools only need it when the tag itself is pushed by a workflow.
- Release events: "Workflows are not triggered for the `created`, `edited`, or `deleted` activity types for draft releases." "If you want a workflow to run when stable and pre-releases publish, subscribe to `published` instead of `released` and `prereleased`." "Events will not be created when more than three tags are pushed at once." [3]
- Immutable releases (GA 2025-10-28): "Once you publish a release as immutable, its assets can't be added, modified, or deleted." "Tags for new immutable releases are protected and can't be deleted or moved." "Existing releases remain mutable unless you republish them." "Attestations use the Sigstore bundle format". [5] "If you have enabled immutable releases for your repository, you cannot add, replace, or delete assets after a release is published". [6] Prescribed sequence: "Create the release as a draft. Attach all associated assets to the draft release. Publish the draft release. This ensures that all assets are in place before the release becomes immutable." Title, notes, prerelease and latest flags stay editable. Enablement "will only apply to future releases". [4]
- REST API: create-release params `tag_name`, `target_commitish`, `draft`, `prerelease`, `make_latest`, `generate_release_notes`, `discussion_category_name`; response includes an `immutable` boolean; "This endpoint triggers notifications. Creating content too quickly using this endpoint may result in secondary rate limiting." [7]
- Inference (mine, not a tool statement): any tool that publishes the release first and uploads assets later (release-please plus a separate upload step, taiki-e's pair, python-semantic-release publish-action) breaks on immutable-enabled repos unless it uses draft mode.

## 3. gh CLI capabilities (item 22, documentation only; we will not use gh)

"If a matching git tag does not yet exist, one will automatically get created from the latest state of the default branch. Use `--target` to point to a different branch or commit". "When using the `create` command to attach assets to a release, separate API calls are made to create the release as a draft, upload the assets, and then publish the release." `--verify-tag`: "Abort in case the git tag doesn't already exist in the remote repository". `--notes-from-tag`: "Fetch notes from the tag annotation or message of commit associated with tag". `--generate-notes`: "Automatically generate title and notes for the release via GitHub Release Notes API". `--latest`: default "automatic based on date and version". `--draft`: "Save the release as a draft instead of publishing it". Also `--fail-on-no-commits`, `--notes-start-tag`, `--discussion-category`. [8] `gh release view --json` exposes `isImmutable`. [9] `gh release verify`: "Verify that a GitHub Release is accompanied by a valid cryptographically signed attestation." `gh release verify-asset`: "validating that the asset's digest matches the subject in the attestation and that the attestation is associated with the release." [10][11] Everything maps to plain REST: create draft, upload assets, PATCH draft=false, attestations API.

## 4. Per-tool details

### 1. release-please (+ release-please-action)
"Release Please automates CHANGELOG generation, the creation of GitHub releases, and version bumps for your projects." "When you're ready to tag a release, simply merge the release PR." `fix:` = patch, `feat:` = minor, `feat!:` = major. "We **highly** recommend that you use squash-merges"; commit override "will not work with plain merges". `Release-As: x.x.x` footer opens a PR for that version. Manifest config: `separate-pull-requests`, `include-component-in-tag`, `draft`, `prerelease`, `prerelease-type`, `bump-minor-pre-major`, `release-as` (remove after merge), `skip-github-release`, plugins node-/cargo-/maven-workspace, linked-versions, sentence-case, group-priority. [12][13][14]
Action: "By default, Release Please uses the built-in `GITHUB_TOKEN` secret. However, all resources created by `release-please` (release tag or release pull request) will not trigger future GitHub actions workflows, and workflows normally triggered by `release.created` events will also not run." Permissions `contents: write`, `issues: write`, `pull-requests: write`. Outputs `release_created`, `tag_name`, `upload_url`, `paths_released`. README examples still `@v4`; v5.0.0 (2026-04-22) breaking change "upgrade to node24". [15][16] No signing/SBOM features. No CalVer mention.

### 2. semantic-release
"Fully automated version management and package publishing"; runs "on the CI environment after every successful build on the release branch". Docs now at semantic-release.org; the repo has no docs/ directory; the gitbook site is discontinued. FAQ: "semantic-release is a Node CLI application, but it can be used to publish any type of packages." Initial 0.0.1 "is not supported by semantic-release." Dry-run previews the version. CI must run it "only after all the tests in the CI build pass". [17][18]
GitHub Actions recipe: "The automatically populated `GITHUB_TOKEN` cannot be used if branch protection is enabled for the target branch." "Personal Access Tokens are not recommended here. They create a broader security risk because a secret exposed to any workflow run can be reused with elevated permissions." `persist-credentials: false`; permissions contents/issues/pull-requests/id-token write; "npm provenance is automatically generated for packages published to npm from GitHub Actions". [19] Monorepo is not covered by the FAQ.

### 3. changesets (+ changesets/action)
"A tool to manage versioning and changelogs with a focus on monorepos"; a changeset is markdown with "a version type (following semver), and change information"; `changeset version` writes per-package changelog entries; site: "Supports pnpm, yarn, and npm workspaces". [20][21][31]
Action v2 (for Changesets v3): opens the "Version Packages" PR; permissions `contents: write`, `pull-requests: write`, `id-token: write` (trusted publishing); "Setting the `GITHUB_TOKEN` environment variable does not configure the action"; `push-with-git-cli` default false, and "When using the GitHub API, commits and tags are signed using GitHub's GPG key and attributed to the user or app that owns the `github-token`." [22] Prereleases: "Prereleases are very complicated!" "Mistakes can lead to repository and publish states that are very hard to fix." [23] The v2 README has no statement about CI on its PRs; the GitHub rule in [1] applies.

### 4. git-cliff (+ git-cliff-action)
"generate changelog files from the Git history by utilizing conventional commits as well as regex-powered custom parsers"; language-agnostic; squash merges recommended. `--bump` "will create a changelog for 1.1.0" from a `feat`; `--bumped-version` prints the next version; `[bump]`: `features_always_bump_minor`, `breaking_always_bump_major`, `initial_tag`, custom major/minor regexes, `bump_type`; nothing on CalVer. Monorepo: run from a subdirectory or `--include-path`/`--exclude-path`. GitHub integration token "without permissions", only to avoid the 60 req/h limit. Action `orhun/git-cliff-action@v4` outputs `content`, `changelog`, `version`. [24][25][26][27][28] Tag/release creation is not a documented feature.

### 5. GoReleaser v2 (+ goreleaser-action)
`release.draft`: "If set to true, will not auto-publish the release. Note: all GitHub releases start as drafts while artifacts are uploaded. Available only for GitHub and Gitea." `mode`: keep-existing (default)/append/prepend/replace; `use_existing_draft` (GitHub only, v2.5+); `replace_existing_draft` (GitHub); `replace_existing_artifacts` (GitHub, GitLab); `make_latest` (GitHub, v2.6+); `prerelease: auto`; `target_commitish` "Useful if you want to delay the creation of the tag in the remote."; `skip_upload`; `disable`. Preflight (v2.18+): "Abort the release before building if a preflight check fails - for instance, when the token lacks permission to publish, or the current tag is already published as an immutable release that cannot be updated." [29]
Builders (all OSS): Rust "Since v2.5" (cargo zigbuild default; "Some options are not supported yet"; workspaces may need `-p`), Zig v2.5, Bun v2.6, Deno v2.6, uv and Poetry v2.9 (wheel/sdist only; "only the GoReleaser target `none-any` is supported"; PyPI publishing is Pro), Python "Coming soon"; cargo publish is Pro. [30][32][33][34][35][36][37]
Pro-only: nightlies ("This feature is exclusively available with GoReleaser Pro"; `version_template`, `publish_release`, `keep_single_release`; "Only works on GitHub"), monorepo, `include`, AI release notes, split/merge builds, prepare-then-publish, DMG/pkg/notarize, custom template variables. [38][39] `homebrew_casks` since v2.10 (versioned casks and `app` are Pro); "you cannot use the default action token" for the tap; `brews` deprecated soft v2.10, hard v2.16. [40][41]
Signing: default `gpg`; cosign keyless `sign-blob --bundle`; artifacts checksum/source/package/installer/archive/sbom/binary (`diskimage` Pro). SBOM via syft, spdx-json default; "Container images generated by GoReleaser are not available to be cataloged by the SBOM tool." Checksums sha256 default plus sha512/sha3/blake2/blake3, `split`. Actions page: permissions contents/packages/id-token/attestations write; `actions/attest-build-provenance` example; PAT with `repo` scope for taps/buckets; `fetch-depth: 0` required. GitLab v12.9+ with 10 MB attachment limit unless generic package registry; Gitea via `GITEA_TOKEN` (Forgejo/Codeberg not named on the page). Changelog `use`: git/github/gitlab/gitea/github-native (github-native supports no grouping/sorting/filtering). Blog 2026-04-26: "no tag we publish can ever be overwritten"; nightlies now `{next-minor}-{sha}-nightly`. [42][43][44][45][46][47][48]

### 6. release-plz
"Version update based on conventional commits", git-cliff "keep a changelog format by default", "API breaking changes detection with cargo-semver-checks", GitHub/Gitea/GitLab releases, git tag per released package. [49] Token page: "GitHub Actions using the default GITHUB_TOKEN cannot trigger other workflow runs."; PAT or GitHub App via `actions/create-github-app-token`; permissions Contents RW, Pull requests RW, Administration RW only for protected tags; `persist-credentials: true` when signing tags. [50] Config: `git_release_draft` ("creates the git release as draft (unpublished)"), `git_release_latest` ("Drafts and prereleases cannot be set as latest"), `git_release_type` prod/pre/auto, `release_always` (GitHub only), `features_always_increment_minor`, `pr_draft`, `dependencies_update`. Semver check applies only to packages with `[lib]` targets. [51][52]

### 7. cargo-release
Extends `cargo publish` with "validation, version management, tagging, and pushing"; dry-run until `--execute`; levels release/patch/minor/major/alpha/beta/rc or an explicit version; nothing inferred from commits. `--workspace`, `--exclude`, `--package`; `shared-version`, `consolidate-commits`, `dependent-version`, `allow-branch`, `push-options`, `rate-limit`. "Use GPG to sign git tag generated by cargo-release." Changelog only via `pre-release-replacements`/`pre-release-hook`. Limitation: dry-run "delegates to `cargo publish` which does not know about the in-memory-only version bump." [53][54]

### 8. knope (+ knope-dev/action)
"Automate tedious tasks, in CI or as a CLI"; versions from change files or conventional commits; "For 0.x versions, packages effectively only have two version components". Versioned files: "Cargo.toml, Cargo.lock, gleam.toml, go.mod, package.json, package-lock.json, deno.json / deno.jsonc, deno.lock, pyproject.toml, pom.xml, pubspec.yaml, tauri.conf.json" plus regex patterns. Forges: "Gitea, GitHub"; monorepo tags `{name}/v{version}`. Release step: "use `on: release: created` to run as soon as the step creates the draft (without assets) or `on: release: published` to run only after the assets are uploaded." Workflow-dispatch recipe uses `secrets.PAT`: "create a fine-grained access token with read/write to 'contents' for only this repo." Changelog headings `## 1.2.3 (2022-12-03)` with type sections. [55][56][57][58][59][60]

### 9. cocogitto
"The Conventional Commits toolbox"; `cog bump --auto` "choose the next version for you"; "cog bump --auto treats 0.y.z versions specially, i.e. it will never do an auto bump to the 1.0.0 version, even if there are breaking changes." Pushing via hooks (`git push origin {{version}}`); no GitHub release creation. Monorepo via `[packages]`; manual bump needs `--include-packages`. Changelog via Tera templates default/full_hash/remote. Action `cocogitto-action@v3` needs `fetch-depth: 0`, pairs with softprops for the release; no token guidance. Latest 7.0.0 (2026-03-04), last push 2026-04-22. [61][62][63][64]

### 10. commitizen
"Automatic keep a changelog generation"; `cz bump` from conventional commits or `--increment`; schemes pep440 (default), semver, semver2; `--annotated-tag`, `--gpg-sign` "Creates gpg signed tags"; `--major-version-zero`; `--get-next`; `--changelog-to-stdout`. Providers: commitizen, scm, pep621, poetry, uv, cargo, npm, composer. GitHub Actions tutorial: "If you use GITHUB_TOKEN instead of PERSONAL_ACCESS_TOKEN, the workflow won't trigger another workflow run." "The GITHUB_TOKEN is treated like using [skip ci]." Release then created by `ncipollo/release-action@v1` with `bodyFile`. [65][66][67][68]

### 11. python-semantic-release
Parsers angular, conventional, conventional-monorepo (v10.4.0), emoji, scipy, tag; remotes github/gitlab/gitea/bitbucket; `allow_zero_version` default false since v10; Markdown or RST via Jinja; `changelog.mode` update. Action: "The `GITHUB_TOKEN` secret is automatically configured by GitHub, with the same permissions role as the user who triggered the workflow run. This causes a problem if your default branch is protected"; `concurrency` "to prevent race conditions of more than one release job"; permissions `id-token: write`, `contents: write`; `root_options` "removed in v10.0.0 and newer because of a command injection vulnerability"; SSH signing key inputs; publish-action uploads dists to the release. "PSR does not yet support a single, workspace-level configuration definition". [69][70][71][72]

### 12. towncrier
"a utility to produce useful, summarized news files"; reads fragments, not git; "it is usable with any project type on any platform" when Python auto-detection is not used; version via `--version` otherwise. Markdown how-to: "Keep a Changelog is a standardized way to format a news file in Markdown."; "Towncrier doesn't have a concept of a 'previous version' (yet)". No tagging, bumping or release creation. [73][74][75]

### 13. softprops/action-gh-release
Permissions `contents: write`; "If a tag already has a GitHub release, the existing release will be updated with the release assets"; `draft`: "When reusing an existing draft release, set this to true to keep it draft; omit it to publish after upload." Immutable note: "Standard releases in this action already upload assets before publishing, but prereleases stay published by default so `release.prereleased` workflows keep firing. On an immutable-release repository, use `draft: true` for prereleases that upload assets, then publish that draft later and subscribe downstream workflows to `release.published`." `make_latest` true/false/legacy; "v2.6.2 is the final v2 release and is no longer maintained or supported...Upgrade to v3, which runs on Node 24". [76]

### 14. ncipollo/release-action
`immutableCreate`: "When enabled, the action will first create a draft, upload artifacts, then publish the release." (default false); `allowUpdates`, `replacesArtifacts` default true, `skipIfReleaseExists`, `updateOnlyUnreleased`, `makeLatest` default "legacy", `generateReleaseNotes`; "If this is omitted the git ref will be used (if it is a tag)"; permissions `contents: write`. [77]

### 15. release-drafter
"Draft the next release notes as pull requests merge into a branch." Label-driven version-resolver and `$RESOLVED_VERSION`; publishing manual unless `publish: true`; `latest` true/false/legacy; `commitish`; GITHUB_TOKEN with `contents: write` (+`pull-requests: write` for autolabeler); CLI needs Node 24+. Notes derive from merged PRs only. [78]

### 16. cargo-dist / dist, including axo.dev status
Generated `release.yml`: `push: tags: '**[0-9]+.[0-9]+.[0-9]+*'` or `workflow_dispatch` (`dispatch-releases`); all checkouts use `persist-credentials: false`; the release step is `gh release create "<tag>" --target "$RELEASE_COMMIT" $PRERELEASE_FLAG --title ... --notes-file ... artifacts/*` (draft->upload->publish per gh semantics), or with `create-release = false` it runs `gh release upload` then `gh release edit ... --draft=false` ("a GitHub Release with this tag is assumed to exist as a draft with the appropriate title/body, and will be undrafted for you"). Attestation via `actions/attest` with `attestations: write` and `id-token: write`; an external release repo needs `GH_RELEASES_TOKEN`. [79][80][81]
Config: `github-attestations` (docs: "currently in public beta"; only "public repositories and private repositories of an organization with the GitHub Enterprise plan"), `checksum` "sha256, sha512, sha3-256, sha3-512, blake2s, blake2b, false", `cargo-auditable`, `cargo-cyclonedx` SBOM, `omnibor`, `ssldotcom-windows-sign`, Azure Artifact Signing (0.33.0), `build-command` for generic projects, `hosting` github or simple, `github-action-commits` for pinned actions; Sigstore signing listed as coming soon; GitHub Actions is the only CI provider. [82][83][84][85]
Status evidence: `opensource.axo.dev` and `blog.axo.dev` did not resolve (DNS) from two networks on 2026-09-24; `axo.dev` still serves a 2023-dated homepage with no notice; docs now live at axodotdev.github.io. CHANGELOG 0.29.0 (2025-07-31): "This is a big release! 0.29.0 includes all of the new features from Astral's fork of dist along with some new bugfixes. It also removes support for Axo Releases." Astral's fork (archived 2025-12-19): "This was an unofficial fork of axodotdev/cargo-dist 0.28.0 to apply minor updates and fixes for astral's projects." and "The upstream project is active again and contains the changes from this fork, please refer to axodotdev/cargo-dist instead." v0.33.0 shipped 2026-09-10 (contributors Gankra, ntBre, blyedev). [86][87][88] No official shutdown announcement was found.

### 17. svu
"a small helper for release scripts and workflows"; `next` reads git log (chore nothing, fix patch, feat minor, `!`/BREAKING major); prints only; tag via `git tag $(svu next)`; `.svu.yml` config; v3.0.0 (2025-02-17) renamed flags (`--always`, `--tag.prefix`, `--tag.pattern`, `--v0`, `--prerelease`, `--log.directory`). [89][90]

### 18. conventional-changelog / standard-version
Monorepo of Node packages (parser, writer, recommended-bump, presets); "We only support Long-Term Support versions of Node."; recommends commit-and-tag-version, semantic-release, simple-release-action for full automation. standard-version: "standard-version is deprecated. If you're a GitHub user, I recommend release-please as an alternative... you can use the commit-and-tag-version fork"; last release v9.5.0, 2022-05-15. [91][92]

### 19. taiki-e/create-gh-release-action and taiki-e/upload-rust-binary-action
create-gh-release-action: "GitHub Action for creating GitHub Releases based on changelog."; Keep a Changelog parsed via parse-changelog; inputs `draft`, `latest`, `allow-missing-changelog`, `branch`, `prefix`; `contents: write`; default `${{ github.token }}`; "Requires bash, GNU tar, curl, git, and GitHub CLI"; pin advice "@v<major>.<minor>.<patch> tag or their hash". upload-rust-binary-action: "basically intended to be used in combination with an action like create-gh-release-action that creates a GitHub release when a tag is pushed"; `checksum` "sha256, sha512, b2, sha1, or md5"; `codesign` macOS; `build-tool` cargo/cross/cargo-zigbuild; "Glob pattern is not supported yet". [93][94]

### 20. mikepenz/release-changelog-builder-action
Builds notes from PRs between tags; modes PR/COMMIT/HYBRID; `platform` github or gitea; read-only contents and pull-requests; PAT only for cross-repo; pin `@v6`; `includeOnlyPaths` for monorepos. [95]

### 21. actions/create-release and actions/upload-release-asset
Both `archived: true`, last push 2021-03-03. READMEs: "This repository is currently unmaintained by a team of developers at GitHub... we are not going to be updating issues or pull requests on this repository." Alternatives named include softprops/action-gh-release and ncipollo/release-action. [96][97]

### 23. Renovate and Dependabot
Renovate: `helpers:pinGitHubActionDigests` = `packageRules` with `matchDepTypes: ["action","workflow"], pinDigests: true`; `helpers:pinGitHubActionDigestsToSemver` adds regex versioning. github-actions manager keeps `uses: actions/checkout@<sha> # v4.0.0` comments; "Actions pinned to a bare SHA without a version comment are disabled by default". nix manager: "supports `lockFileMaintenance` updates for `flake.lock`" and "input updates for `flake.lock`"; docs mark it beta with `"enabled": false` by default; datasource `git-refs`. `lockFileMaintenance`: "By default, `lockFileMaintenance` is disabled."; runs `"before 4am on monday"`. Self-hosted PAT "must have the `repo` scope. If you want Renovate to also update your GitHub Action files, you must grant the `workflow` scope."; App permissions include Contents, Pull requests, Workflows, Checks, Commit statuses, Issues RW. Mend app: "free to install for both public and private repositories". [98][99][100][101][102][103]
Dependabot: since 2022-10-31 it "will now update the semver version in comments when updating Actions workflows with a commit SHA version." Cooldown table: GitHub Actions supports `default-days` only (no `semver-*-days`); default 3-day cooldown for version updates since 2026-07-14 ("Security updates still open immediately"). Nix ecosystem since 2026-04-07: "monitor your `flake.lock` inputs and open pull requests when newer commits are available upstream"; "GitHub, GitLab, Sourcehut, and plain git inputs are all supported"; version updates only; no private repos; pinned refs inside flake.nix are not updated. [104][105][106][107]

### 24. DeterminateSystems/update-flake-lock and flake-checker-action
update-flake-lock (v29, 2026-09-09): "GitHub Actions doesn't run workflows when a branch is pushed by or a PR is opened by a GitHub Action."; fix is a PAT with `repo` scope or fine-grained Contents + Pull Requests RW, or "close and reopen the pull request manually"; example permissions `contents: write`, `id-token: write`, `issues: write`, `pull-requests: write`; GPG commit signing inputs; example uses `determinate-nix-action@v3`. No GitHub App guidance and no deprecation notice. flake-checker-action (v14, 2026-09-09): checks nixpkgs inputs "updated within the last 30 days", NixOS-owned, supported branch; no token, no Nix install needed; `send-statistics` default true; pin `@vN`. [108][109]

## 5. Could not verify

- (a) Any formal axo.dev shutdown or wind-down announcement (blog host unreachable; company homepage silent).
- (b) The Mend Renovate App's exact permission list (not on the app page).
- (c) release-plz tag signing (no signing option documented).
- (d) cocogitto tag signing and token guidance.
- (e) A tool-documented statement in changesets v2 or knope about GITHUB_TOKEN-created PRs not running CI (GitHub's rule applies regardless).
- (f) git-cliff's default template being Keep a Changelog compliant.
- (g) cargo-dist's Homebrew tap secret name.
- (h) svu's full v3 flag list beyond the v3.0.0 release notes.
- (i) release-please CalVer support (no mention found; treated as unsupported).

## 6. Sources (all accessed 2026-09-24)

1. https://docs.github.com/en/actions/concepts/security/github_token
2. https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow
3. https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
4. https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases
5. https://github.blog/changelog/2025-10-28-immutable-releases-are-now-generally-available/
6. https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
7. https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28
8. https://cli.github.com/manual/gh_release_create
9. https://cli.github.com/manual/gh_release_view
10. https://cli.github.com/manual/gh_release_verify
11. https://cli.github.com/manual/gh_release_verify-asset
12. https://raw.githubusercontent.com/googleapis/release-please/main/README.md
13. https://github.com/googleapis/release-please
14. https://raw.githubusercontent.com/googleapis/release-please/main/docs/manifest-releaser.md
15. https://raw.githubusercontent.com/googleapis/release-please-action/main/README.md
16. https://github.com/googleapis/release-please-action/releases/tag/v5.0.0
17. https://github.com/semantic-release/semantic-release
18. https://semantic-release.org/support/faq/
19. https://semantic-release.org/recipes/ci-configurations/github-actions/
20. https://raw.githubusercontent.com/changesets/changesets/main/README.md
21. https://github.com/changesets/changesets/blob/main/docs/intro-to-using-changesets.md
22. https://raw.githubusercontent.com/changesets/action/main/README.md
23. https://github.com/changesets/changesets/blob/main/docs/prereleases.md
24. https://git-cliff.org/docs/
25. https://git-cliff.org/docs/usage/bump-version
26. https://git-cliff.org/docs/configuration/bump
27. https://git-cliff.org/docs/usage/monorepos
28. https://git-cliff.org/docs/integration/github and https://raw.githubusercontent.com/orhun/git-cliff-action/main/README.md
29. https://goreleaser.com/customization/release/
30. https://goreleaser.com/customization/builds/
31. https://changesets.dev/
32. https://goreleaser.com/customization/builds/builders/rust/
33. https://goreleaser.com/customization/builds/builders/zig/
34. https://goreleaser.com/customization/builds/builders/bun/
35. https://goreleaser.com/customization/builds/builders/deno/
36. https://goreleaser.com/customization/builds/builders/uv/ and https://goreleaser.com/customization/builds/builders/poetry/
37. https://goreleaser.com/customization/builds/builders/python/
38. https://goreleaser.com/pro/
39. https://goreleaser.com/customization/nightlies/
40. https://goreleaser.com/customization/homebrew_casks/
41. https://goreleaser.com/deprecations/
42. https://goreleaser.com/customization/sign/
43. https://goreleaser.com/customization/sbom/
44. https://goreleaser.com/customization/checksum/
45. https://goreleaser.com/ci/actions/ and https://raw.githubusercontent.com/goreleaser/goreleaser-action/master/README.md
46. https://goreleaser.com/scm/gitlab/ and https://goreleaser.com/scm/gitea/
47. https://goreleaser.com/customization/changelog/
48. https://goreleaser.com/blog/immutable-releases/
49. https://release-plz.dev/docs
50. https://release-plz.dev/docs/github/token
51. https://release-plz.dev/docs/config
52. https://release-plz.dev/docs/semver-check
53. https://raw.githubusercontent.com/crate-ci/cargo-release/main/README.md
54. https://raw.githubusercontent.com/crate-ci/cargo-release/main/docs/reference.md
55. https://knope.tech/
56. https://knope.tech/reference/config-file/packages/
57. https://knope.tech/reference/config-file/steps/release/
58. https://knope.tech/reference/concepts/forge/ and https://knope.tech/reference/concepts/semantic-versioning/
59. https://knope.tech/recipes/workflow-dispatch-releases/
60. https://knope.tech/reference/concepts/changelog/
61. https://raw.githubusercontent.com/cocogitto/cocogitto/main/README.md
62. https://docs.cocogitto.io/guide/bump.html
63. https://docs.cocogitto.io/guide/monorepo.html and https://docs.cocogitto.io/guide/changelog.html
64. https://docs.cocogitto.io/ci_cd/action.html and https://raw.githubusercontent.com/cocogitto/cocogitto-action/main/README.md
65. https://commitizen-tools.github.io/commitizen/
66. https://commitizen-tools.github.io/commitizen/commands/bump/
67. https://commitizen-tools.github.io/commitizen/tutorials/github_actions/
68. https://commitizen-tools.github.io/commitizen/config/version_provider/
69. https://python-semantic-release.readthedocs.io/en/latest/
70. https://python-semantic-release.readthedocs.io/en/latest/configuration/automatic-releases/github-actions.html
71. https://python-semantic-release.readthedocs.io/en/latest/configuration/configuration.html
72. https://python-semantic-release.readthedocs.io/en/latest/configuration/configuration-guides/monorepos.html
73. https://towncrier.readthedocs.io/en/stable/
74. https://towncrier.readthedocs.io/en/stable/configuration.html
75. https://towncrier.readthedocs.io/en/stable/markdown.html
76. https://raw.githubusercontent.com/softprops/action-gh-release/master/README.md
77. https://raw.githubusercontent.com/ncipollo/release-action/main/README.md
78. https://raw.githubusercontent.com/release-drafter/release-drafter/main/README.md
79. https://raw.githubusercontent.com/axodotdev/cargo-dist/main/cargo-dist/templates/ci/github/release.yml.j2
80. https://raw.githubusercontent.com/axodotdev/cargo-dist/main/cargo-dist/templates/ci/github/partials/publish_github.yml.j2
81. https://raw.githubusercontent.com/axodotdev/cargo-dist/main/cargo-dist/src/backend/ci/github.rs
82. https://raw.githubusercontent.com/axodotdev/cargo-dist/main/book/src/reference/config.md
83. https://axodotdev.github.io/cargo-dist/book/supplychain-security/attestations/github.html
84. https://raw.githubusercontent.com/axodotdev/cargo-dist/main/book/src/supplychain-security/index.md
85. https://axodotdev.github.io/cargo-dist/book/ci/index.html and https://axodotdev.github.io/cargo-dist/book/ci/customizing.html
86. https://raw.githubusercontent.com/axodotdev/cargo-dist/main/CHANGELOG.md (0.29.0 and 0.33.0 entries)
87. https://github.com/astral-sh/cargo-dist
88. https://axo.dev/ and https://github.com/axodotdev (plus DNS checks on opensource.axo.dev and blog.axo.dev)
89. https://raw.githubusercontent.com/caarlos0/svu/main/README.md
90. https://github.com/caarlos0/svu/releases/tag/v3.0.0
91. https://raw.githubusercontent.com/conventional-changelog/conventional-changelog/master/README.md
92. https://raw.githubusercontent.com/conventional-changelog/standard-version/master/README.md
93. https://raw.githubusercontent.com/taiki-e/create-gh-release-action/main/README.md
94. https://raw.githubusercontent.com/taiki-e/upload-rust-binary-action/main/README.md
95. https://raw.githubusercontent.com/mikepenz/release-changelog-builder-action/develop/README.md
96. https://raw.githubusercontent.com/actions/create-release/main/README.md
97. https://raw.githubusercontent.com/actions/upload-release-asset/main/README.md
98. https://docs.renovatebot.com/presets-helpers/
99. https://docs.renovatebot.com/modules/manager/github-actions/
100. https://docs.renovatebot.com/modules/manager/nix/ and https://raw.githubusercontent.com/renovatebot/renovate/main/lib/modules/manager/nix/readme.md
101. https://raw.githubusercontent.com/renovatebot/renovate/main/docs/usage/configuration-options.md (lockFileMaintenance)
102. https://docs.renovatebot.com/modules/platform/github/
103. https://github.com/apps/renovate and https://docs.renovatebot.com/getting-started/installing-onboarding/
104. https://github.blog/changelog/2022-10-31-dependabot-now-updates-comments-in-github-actions-workflows-referencing-action-versions/
105. https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference
106. https://github.blog/changelog/2026-07-14-dependabot-version-updates-introduce-default-package-cooldown/
107. https://github.blog/changelog/2026-04-07-dependabot-version-updates-now-support-the-nix-ecosystem/ and https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories
108. https://raw.githubusercontent.com/DeterminateSystems/update-flake-lock/main/README.md and https://api.github.com/repos/DeterminateSystems/update-flake-lock
109. https://raw.githubusercontent.com/DeterminateSystems/flake-checker-action/main/README.md and https://api.github.com/repos/DeterminateSystems/flake-checker-action
110. GitHub REST API `/repos/<owner>/<repo>` and `/releases/latest` for all 32 repositories, fetched 2026-09-24T05:24Z (raw output in `../meta.out`)
