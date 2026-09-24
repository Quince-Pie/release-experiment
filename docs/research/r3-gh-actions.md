<!-- Research digest produced for this repository on 2026-09-24 from primary sources only (specifications, official documentation, changelogs, official repositories). Quotes are verbatim; every source URL and its access date are listed at the end. Items the research could not verify are listed explicitly. -->

# GitHub Actions as a release-build platform, 2025–2026 (supply-chain focus)

Research agent r3-gh-actions. All sources accessed 2026-09-24. Primary sources only (GitHub Docs, GitHub Changelog/Blog, official `actions/*` and other action repositories, GHSA/CVE, CISA, OpenSSF/Sigstore, GitHub's `cli/cli`). Bracketed `[S#]` references point to the numbered source list at the end.

**Method for the version table.** Latest tag = `github.com/<repo>/releases/latest` redirect. Commit SHA = `git ls-remote --tags` peeled `^{}` commit for annotated tags, or the ref itself for lightweight tags. Runtime = `runs.using` in `action.yml` at that tag. Dates from the REST API for the first eight repos and from each repo's `releases.atom` afterwards (the unauthenticated REST limit ran out mid-way). Raw data: `scratchpad/q4_out.txt` and `scratchpad/tags_*.txt`.

---

## 1. SHA pinning, policy, Dependabot

- **Docs guidance** [S1]: "Pinning an action to a full-length commit SHA is currently the only way to use an action as an immutable release." Docs pair this with Dependabot version updates.
- **Policy to require pinning**, changelog 2025-08-15 [S2]: administrators can "enforce the use of SHA pinning through the allowed actions policy... any workflow that attempts to use an action that isn't pinned will fail." The same entry added blocking: "Prefix an entry with `!` to block", blocklist evaluated last. The checkbox appears "under each radio selection, except when actions are disabled".
- **Exact setting name** (org docs [S3], repo docs [S4]): **"Require actions to be pinned to a full-length commit SHA"**. Scope text: "all actions must be pinned to a full-length commit SHA to be used. This includes actions from your organization and actions authored by GitHub. Reusable workflows can still be referenced by tag." Local `./` and `$/` references are exempt. Levels: enterprise, organization, repository.
- **REST API** [S5][S6]: boolean `sha_pinning_required` on GET/PUT `/enterprises/{enterprise}/actions/permissions`, `/orgs/{org}/actions/permissions`, `/repos/{owner}/{repo}/actions/permissions`. Example bodies from the docs:

  ```json
  {"enabled_repositories": "all", "allowed_actions": "selected", "sha_pinning_required": true}
  {"enabled": true, "allowed_actions": "selected", "sha_pinning_required": true}
  ```

  Allow-list body (`.../permissions/selected-actions`): `github_owned_allowed`, `verified_allowed`, `patterns_allowed` (a pattern such as `"!space-org/action@*"` blocks). Allow-listing became available on all plans 2026-02-05 [S7].
- **Same-repo references without SHA churn**, 2026-07-30 [S8]: "A `uses:` value that starts with `$/` resolves to your workflow's own repository at the exact commit that is running." Requires runner 2.336.0.
- **Dependabot keeps the version comment current** since 2022-10-31 [S9]: "Dependabot will now update the semver version in comments when updating Actions workflows with a commit SHA version." (only when the version is the last thing in the comment). Ecosystem `github-actions` with `directory: "/"` scans `.github/workflows` plus the root `action.yml` [S10].
- **`cooldown`** [S10]: keys `default-days`, `semver-major-days`, `semver-minor-days`, `semver-patch-days`, `include`, `exclude` (≤150 entries each, wildcards; "The `exclude` list always take precedence over the `include` list"). GitHub Actions supports `default-days`; the semver-specific keys are listed for other ecosystems. Since 2026-07-14 a default applies [S11]: "Dependabot now waits until a new release has been available on its registry for at least three days before opening a version update pull request." Security updates are not delayed.
- **`groups`** [S10]: `applies-to` (`version-updates` | `security-updates`), `dependency-type`, `patterns`, `exclude-patterns`, `update-types` (`patch` | `minor` | `major`), `group-by: dependency-name`. Combined example consistent with the reference:

  ```yaml
  version: 2
  updates:
    - package-ecosystem: "github-actions"
      directory: "/"
      schedule: { interval: "weekly" }
      cooldown: { default-days: 7 }
      groups:
        actions-minor-patch:
          patterns: ["*"]
          update-types: ["minor", "patch"]
  ```

## 2. Immutable Actions: stopped; replaced by the SHA-pinning policy and immutable releases

- Both roadmap items are **"Closed as not planned"**: "Immutable Actions [GA]" (#592) [S12] and "Immutable Actions Publishing [Public Preview]" (#1103) [S13].
- GitHub's Actions product lead (nebuk89, GitHub staff, 2025-12-16, official community discussion) [S14]: "we made the hard call to 'stop' immutable Actions in the form it was in, and instead we shipped an org setting for enforcing sha pinning." Reason: "we took down our registry a few times and sunk time in hardening the registry". In the 2026 roadmap thread a GitHub staffer (Steve-Glass, 2026-03-27) wrote "This is something we plan to address this year." [S15]
- CodeQL 2.20.6, 2025-03-06 [S16]: "The `actions/unversioned-immutable-action` query will no longer report any alerts, since the Immutable Actions feature is not yet available for customer use."
- **Design as planned**: OCI packages in GHCR published by `actions/publish-immutable-action` (README: "not ready for public use"), consumed as `uses: your-name/your-action@v1.2.3`; runners needed egress to `pkg.actions.githubusercontent.com` and `ghcr.io` [S17][S18].
- **`actions/checkout` and the other GitHub actions are not published as packages**: the `actions` org package list has no package for checkout, upload-artifact, cache or attest, and `github.com/actions/checkout/pkgs/container/checkout` returns 404 [S19].
- **No "require immutable actions" policy exists.** Shipped replacements: the SHA-pinning policy (section 1); immutable releases GA 2025-10-28 [S20] ("Once you publish a release as immutable, its assets can't be added, modified, or deleted."; "Tags for new immutable releases are protected and can't be deleted or moved."; "Immutable releases receive signed attestations"); and a planned workflow `dependencies:` lock section (roadmap post 2026-03-26: "locks all direct and transitive dependencies with the commits SHA", public preview "in 3-6 months") [S21].

## 3. Runtime and runners

- **Node timeline** [S22] (entry 2025-09-19, edited 2026-02-25, 2026-05-19, 2026-08-25): "The newest GitHub runner (v2.328.0) now supports both Node20 and Node24 and uses Node20 as the default version." "Beginning on June 16th, 2026, runners will begin using Node24 by default." Node 20 is removed "on September 23rd, 2026." Early opt-in: `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`. Temporary opt-out: `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true`. Node 24 does not run on macOS ≤13.4 or ARM32.
- **Observed state**: latest runner is v2.337.0 (2026-08-26) and `main` still fetches Node 20 (`NODE20_VERSION="20.20.2"`, `NODE24_VERSION="24.21.0"`) [S23]. No release removing Node 20 was visible at access time, one day after the announced date.
- **Images** (runner-images README) [S24]: `ubuntu-latest` = Ubuntu 24.04. `ubuntu-26.04` and `ubuntu-26.04-arm` GA 2026-09-17, with `ubuntu-latest` migrating to 26.04 between 2026-10-19 and 2026-11-19 [S25]. `ubuntu-22.04` / `ubuntu-22.04-arm` still listed. `ubuntu-slim` (1 vCPU, 5 GB, runs in a container, 15-minute job cap; GA 2026-01-22) [S26]. macOS: `macos-latest` = macOS 26 arm64 (`macos-26`, `macos-26-xlarge`; Intel `macos-26-intel` / `macos-26-large`), `macos-15` (+ `-xlarge`, `-large`, `-intel`), `macos-14` deprecated, `xcode-27` preview; `macos-latest` moved to macOS 26 starting 2026-06-15 [S27]. Windows: `windows-latest` = `windows-2025` (Visual Studio 2026 since June 2026), `windows-11-arm`, `windows-11-vs2026-arm`.
- **arm64 hosted runners for public repos**: free preview 2025-01-16; GA 2025-08-07 [S28]: "Linux and Windows arm64 standard hosted runners in public repositories are generally available", labels `ubuntu-24.04-arm`, `ubuntu-22.04-arm`, `windows-11-arm`, 4 vCPU, no cost. Since 2026-01-29 also in private repos (2 vCPU there, counting toward plan minutes) [S29]. Arm images are now maintained by GitHub [S27].
- **Pricing** [S30][S31][S32]: hosted-runner prices cut "by up to 39%" on 2026-01-01; "Standard hosted runner usage in public repositories remains free." A $0.002/min self-hosted charge announced for 2026-03-01 was withdrawn: "We're postponing the announced billing change for self-hosted GitHub Actions to take time to re-evaluate our approach." Current list prices: Linux 2-core x64 $0.006/min, Linux arm64 2-core $0.005, Windows 2-core $0.010, macOS $0.062; "The larger runners are not free for public repositories."
- **Self-hosted minimum runner** 2.329.0 plus a 30-day upgrade window, enforced on GitHub Enterprise Cloud from 2026-09-25 [S33].

## 4. Official action versions

| Action | Latest tag (date) | Commit SHA | `runs.using` | Floating major |
|---|---|---|---|---|
| actions/checkout | v7.0.1 (2026-07-20) | `3d3c42e5aac5ba805825da76410c181273ba90b1` | node24 | v7 = same |
| actions/upload-artifact | v7.0.1 (2026-04-10) | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | node24 | v7 = same |
| actions/download-artifact | v8.0.1 (2026-03-11) | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` | node24 | v8 = same |
| actions/attest-build-provenance | v4.2.2 (2026-08-06) | `4d101475d8b20a2381f78447822ac1eab6504dd8` | composite (wraps actions/attest) | v4 = same |
| actions/attest-sbom | v4.1.0 (2026-03-18) | `c604332985a26aa8cf1bdc465b92731239ec6b9e` | composite (deprecated wrapper) | v4 = same |
| actions/attest | v4.2.2 (2026-08-04) | `1e69f48acb82d1966a394da916b4c1698aa569d6` | node24 | v4 = same |
| actions/create-github-app-token | v3.2.0 (2026-05-12) | `bcd2ba49218906704ab6c1aa796996da409d3eb1` | node24 | v3 = same |
| actions/setup-go | v7.0.0 (2026-07-16) | `b7ad1dad31e06c5925ef5d2fc7ad053ef454303e` | node24 | v7 = same |
| actions/cache | v6.1.0 (2026-06-26) | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | node24 | v6 = same |
| actions/github-script | v9.0.0 (2026-04-09) | `3a2844b7e9c422d3c10d287c895573f7108da1b3` | node24 | v9 = same |
| github/codeql-action | v4.38.1 (2026-09-18) | `1c5b675653bb5c22dbe9b12b556ec555138e09fd` | node24 (init, analyze, upload-sarif) | v4 = same |
| ossf/scorecard-action | v2.4.4 (2026-07-23) | `2d1146689b8cda280b9bc96326124645441f03bc` | docker | no v2 tag |
| step-security/harden-runner | v2.21.1 (2026-08-30) | `e14015d583714f6e62063499dc959a02595150a1` | node24 | v2 = same |
| zizmorcore/zizmor-action | v0.6.4 (2026-09-09) | `cc914d7f3750a2d13d75c7f184a1060aa0e9d482` | composite | no v0 tag |
| DeterminateSystems/nix-installer-action | v23 (2026-09-09) | `3138316df39ed29be04236d7ffc686fa525866aa` | node24 | integer majors |
| cachix/install-nix-action | v31.11.1 (2026-08-13) | `13d8dd58da0234aa297dedd986986ccb8e7f3e24` | composite | v31 = same |
| nixbuild/nix-quick-install-action | v35 (2026-06-17) | `9f63be77f412a248c9d9a65a4c82cf066cdf8f0c` | composite | integer majors |
| anchore/sbom-action | v0.24.2 (2026-08-28) | `3ad7283483fc7af8ff2b4ea19663c2d5ca935e26` | node24 | v0 = `e22c389904149dbc22b58101806040fa8d37a610` (= v0.24.0, **stale**) |
| sigstore/cosign-installer | v4.1.2 (2026-05-07) | `6f9f17788090df1f26f669e9d70d6ae9567deba6` | composite | no v4 tag |
| softprops/action-gh-release | v3.0.3 (2026-08-30) | `efb35369e0ad2afab669f228072c1b0d510eae64` | node24 | v3 = same |

Notes:

- `github/codeql-action`'s `releases/latest` redirect points at the CodeQL bundle release (`codeql-bundle-v2.27.1`, 2026-09-22). The action's own latest tag is `v4.38.1`, an annotated tag (tag object `c23de5a8…`) whose commit is the SHA listed.
- Version history relevant to release pipelines: checkout v5.0.0 (2025-08-11) moved to Node 24 with minimum runner 2.327.1; v6.0.0 (2025-11-20) stores credentials "in a separate file under `$RUNNER_TEMP` instead of directly in `.git/config`" [S34]; v7.0.0 (2026-06-18) blocks fork-PR checkout under `pull_request_target`/`workflow_run`, backported as v6.1.0, v5.1.0, v4.4.0, v3.7.0, v2.8.0 on 2026-07-20 [S35]. upload-artifact v6.0.0 (2025-12-12) requires runner ≥2.327.1; v7.0.0 (2026-02-26) is ESM and adds `archive: false` [S36]. cache v5.0.0 (2025-12-11) needs runner ≥2.327.1; v6.0.0 (2026-06-23) ESM; v6.1.0/v5.1.0 (2026-06-26) handle read-only cache tokens [S37]. download-artifact v7.0.0 (2025-12-12), v8.0.0 (2026-03-11).

## 5. Artifact attestations

- **Concept doc** [S38]: "Artifact attestations by itself provides SLSA v1.0 Build Level 2." For Level 3: "Reusable workflows can provide isolation between the build process and the calling workflow, to meet SLSA v1.0 Build Level 3." Public repos "use the Sigstore Public Good Instance" and bundles are "written to an immutable transparency log that is publicly readable"; private repos "use GitHub's Sigstore instance" which "does not have a transparency log and only federates with GitHub Actions". Private/internal repos need GitHub Enterprise Cloud; unsupported on GHES [S39].
- **Permissions** [S40]: `id-token: write`, `contents: read`, `attestations: write` (plus `packages: write` for registry push). Docs now show `actions/attest@v4` for both provenance and SBOM. `attest-build-provenance` v4 is "simply a wrapper on top of `actions/attest`" [S41]; `attest-sbom` "is being deprecated in favor of `actions/attest`" and prints a deprecation warning at run time [S42].
- **Inputs** (from `action.yml` at v4.2.2 [S43]): `subject-path` (glob or list; "total subject count cannot exceed 1024"), `subject-digest` (`algorithm:hex_digest`), `subject-name` (required with digest), `subject-checksums` (shasum-style file), `predicate-type` / `predicate` / `predicate-path` (custom predicates, ≤16 MB), `push-to-registry` (default false; needs a fully qualified image name plus digest), `create-storage-record` (default true, only with push), `show-summary` (default true), `github-token`. Outputs: `bundle-path`, `attestation-id`, `attestation-url`, `storage-record-ids`. `actions/attest` adds `sbom-path` ("SPDX or CycloneDX" JSON, ≤16 MB) and `subject-version`, and with no subject input "subjects are discovered from the runner-provided $GITHUB_ARTIFACTS_LIST". `attest-sbom`: same subject inputs plus required `sbom-path`; formats "either the SPDX or CycloneDX JSON-serialized format" (no version list given).
- **Limit** [S39]: "No more than 1024 subjects can be attested at the same time."
- **Verification with gh** [S44]: `--owner` or `--repo` required; defaults `--cert-oidc-issuer https://token.actions.githubusercontent.com` and `--predicate-type https://slsa.dev/provenance/v1`; policy flags `--signer-workflow [host/]<owner>/<repo>/<path>/<to>/<workflow>`, `--signer-repo`, `--cert-identity` (exact SAN), `--cert-identity-regex`, `--deny-self-hosted-runners`, `--source-ref`, `--source-digest`; offline `--bundle`, `--bundle-from-oci`, `--custom-trusted-root`, `--no-public-good`. Immutable releases add `gh release verify` and `gh release verify-asset` [S45].
- **Without gh**: REST `GET /repos/{owner}/{repo}/attestations/{subject_digest}` (`sha256:HEX`; `predicate_type` filter accepts "provenance, sbom, release, or freeform text"; `per_page` ≤100; each item carries `repository_id` and `bundle_url`, and under API version 2022-11-28 also the inline `bundle` {`mediaType`, `verificationMaterial`, `dsseEnvelope`}) [S46]. Owner-level list, bulk-list and delete endpoints live under `/users/{username}/attestations/...` [S47]. The offline doc says "First, get the attestation bundle from the attestation API." then verify with `--bundle` and `--custom-trusted-root trusted_root.jsonl` (from `gh attestation trusted-root`) [S48]. GitHub Docs never name cosign or sigstore-go; the immutable-releases changelog says bundles work "with any Sigstore-compatible tooling" [S20]. The Kubernetes guide uses Sigstore Policy Controller with GitHub's `trust-policies` Helm chart (issuer default `https://token.actions.githubusercontent.com`, identity regex like `^https://github.com/OWNER/REPO/`) [S49][S50].
- **Identity convention**: Fulcio (Sigstore, an OpenSSF project) builds the SAN as `https://github.com/{job_workflow_ref}`, example `https://github.com/octo-org/octo-automation/.github/workflows/oidc.yml@refs/heads/main` [S51]. GitHub's OIDC reference gives `workflow_ref` as `octocat/hello-world/.github/workflows/my-workflow.yml@refs/heads/my_branch` [S52]. A tag release therefore verifies against `https://github.com/OWNER/REPO/.github/workflows/release.yml@refs/tags/v1.0.0` with issuer `https://token.actions.githubusercontent.com`. Fulcio extensions: 1.3.6.1.4.1.57264.1.8 issuer; .9 Build Signer URI (server_url + job_workflow_ref); .12 Source Repository URI; .18 Build Config URI [S53].
- **Changelog trail**: 2025-02-18 [S54] default predicate is provenance, evaluated policies printed, checksum-file input, and "Verification now succeeds if at least one attestation passes verification"; 2025-07-01 [S55] deletion, filtering, bulk endpoints; 2025-08-26 immutable releases preview; 2025-10-28 GA with release attestations [S20]; 2026-01-20 [S56] storage/deployment records, "helping you achieve SLSA Build Level 3"; 2026-03-10 API version removes the inline `bundle` (see section 9); 2026-08-27 retention change [S57] does not mention attestations.

## 6. Hardening

- **Least privilege** [S1]: "make sure that the `GITHUB_TOKEN` is granted the minimum required permissions." Syntax [S58]: scopes now include `artifact-metadata`, `attestations`, `code-quality`, `id-token`, `vulnerability-alerts` (read/none, added 2026-09-03 [S59]); "If you specify the access for any of these permissions, all of those that are not specified are set to none."; `permissions: {}` disables all. A release job needs `contents: write` (to upload assets), `id-token: write`, `attestations: write`, optionally `packages: write`.
- **Default token permissions**: personal repos default to read on `contents`/`packages`; new organizations default to "Read"; separate toggle "Allow GitHub Actions to create and approve pull requests" [S3][S4]. REST: `default_workflow_permissions` (`read` | `write`) and `can_approve_pull_request_reviews` on `/repos/{owner}/{repo}/actions/permissions/workflow` and the org/enterprise equivalents [S5][S6].
- **`pull_request_target`** [S1]: "The `pull_request_target` and `workflow_run` workflow triggers, when used with the checkout of an untrusted pull request, expose the repository to security compromises." Checkout v7 now "refuses to fetch fork pull request code in `pull_request_target` and `workflow_run` workflows"; the opt-out input is `allow-unsafe-pr-checkout`; backports enforced from 2026-07-20 [S35]. From 2026-09-17 a default policy disables `pull_request_target` in public repos without event policies, enforced 2026-11-02 [S60]. Untrusted triggers get read-only cache tokens (2026-06-26) [S61]; `cache-mode: read | write | write-only | none` per job or workflow, default `read` for low-trust events (2026-09-10) [S62].
- **Script injection** [S1]: "the preferred approach to handling untrusted input is to set the value of the expression to an intermediate environment variable."
- **`persist-credentials`** [S34]: default true; "Set `persist-credentials: false` to opt-out."
- **Environments** [S63]: "You can list up to six users or teams as reviewers."; self-review prevention; wait timer 1–43,200 minutes; "Selected branches and tags" patterns (tag patterns gate release deploys); custom GitHub-App protection rules (max 6); admin bypass on by default and can be disabled. Private-repo environments need Pro/Team/Enterprise.
- **Workflow execution protections** (rulesets with actor and event rules, evaluate mode): preview 2026-06-18 [S64], GA 2026-09-17 [S60]; example from the entry: "Limit `workflow_dispatch` to maintainers so untrusted identities can't kick off workflows."
- **CodeQL for workflows** GA 2025-04-22 [S65]: default setup "automatically enable[s] Actions workflow analysis when workflow files are detected"; advanced setup adds the `actions` language; Copilot Autofix for `actions/missing-workflow-permissions`; GHES 3.18. 2026-09-03: "The `actions/unpinned-tag` query now detects mutable references to reusable workflows." [S66]
- **OpenSSF Scorecard** [S67]: Signed-Releases (High) scans the 30 most recent releases for `*.minisig, *.asc, *.sig, *.sign, *.sigstore, *.sigstore.json, *.intoto.jsonl`; "If a SLSA provenance file is found in the assets for each release (*.intoto.jsonl), the maximum score of 10 is given." GitHub attestations are not mentioned. Pinned-Dependencies (Medium): hash-pin actions and Docker images. Token-Permissions (High): top-level read-only, job-level writes. Dangerous-Workflow (Critical): untrusted checkout and script injection. Branch-Protection (High): reviews, status checks, no force-push on default and release branches.

## 7. Incidents

- **tj-actions/changed-files**, CVE-2025-30066, GHSA-mrrh-fwg8-r2c3, published 2025-03-15, CVSS 8.6 [S68]: tags retroactively repointed to commit `0e58ed8671d6b60d0890c21b07f8835ace038e67`, which "extracted secrets from the Runner Worker process memory and printed them in GitHub Actions logs"; window 2025-03-12 00:00 to 2025-03-15 12:00 UTC; fixed in 46.0.1. CISA alert 2025-03-18 [S69]: "Rotate all identified secrets immediately as they should be considered compromised"; pin per GitHub's guidance.
- **reviewdog/action-setup**, CVE-2025-30154, GHSA-qmg3-hpqr-gqvc, published 2025-03-19, CVSS 8.6 [S70]: `v1` compromised 2025-03-11 18:42–20:31 UTC (commit `f0d342d`, fix `3f401fe`); code "dumps exposed secrets to Github Actions Workflow Logs"; downstream reviewdog actions affected. Mitigation: pin to SHA, rotate.
- **Nx "s1ngularity"**, GHSA-cxm3-wv7p-598c, 2025-08-27 [S71]: a `pull_request_target` workflow with bash injection yielded elevated tokens; the attacker "altered the behavior of the `publish.yml` pipeline to send the npm token to a webhook"; malicious postinstall harvested credentials. Mitigation: rotate, Trusted Publisher, 2FA.
- **Shai-Hulud**, GitHub notified 2025-09-14 [S72]: "a self-replicating worm that infiltrated the npm ecosystem via compromised maintainer accounts by injecting malicious post-install scripts"; 500+ packages removed. npm changes: mandatory 2FA for local publishing, "Granular tokens which will have a limited lifetime of seven days", trusted publishing, classic tokens deprecated (creation disabled 2025-11-05, revoked 2025-12-09 [S73][S74]), TOTP deprecated for FIDO, tokens disallowed for publishing by default. The second wave (November 2025) added "endpoint command and control via self-hosted runner registration" and CI-targeted privilege escalation [S75].
- **GhostAction**: no GHSA, CVE, CISA, GitHub, or OpenSSF source found. Unverified.
- **2026 — Trivy / TeamPCP**, CVE-2026-33634, GHSA-69fq-xp46-6x23, published 2026-03-21, critical [S76]: after a late-February credential compromise and a non-atomic rotation, attackers on 2026-03-19 published malicious trivy v0.69.4 and force-pushed 76 of 77 `trivy-action` tags plus all 7 `setup-trivy` tags to infostealer commits; mitigation "Pin GitHub Actions to full commit SHA hashes", rotate, upgrade (trivy-action ≥0.35.0, setup-trivy ≥0.2.6).
- **2026 — TanStack**, CVE-2026-45321, GHSA-g7cv-rxg3-hmpx, 2026-05-11, CVSS 9.6 [S77]: 84 malicious versions across 42 packages via a chain of `pull_request_target` "Pwn Request", cache poisoning across the fork boundary, and OIDC token extraction from the runner; "The publishes were authenticated via the legitimate GitHub Actions OIDC trusted-publisher binding."
- **2026 — GitHub internal repositories**, 2026-05-18 [S78][S79]: an employee device was compromised by poisoned Nx Console 18.95.0 (CVE-2026-48027, on CISA KEV); roughly 3,800 internal repos were exfiltrated and the GHES signing key rotated. CISA's alert also cites the "Megalodon" campaign, which "injected malicious GitHub Action workflows to harvest CI/CD secrets, cloud credentials, and tokens", advising audits of workflow changes after 2026-05-18 and full secret rotation. GitHub's 2026-07-28 mitigation summary: safer checkout defaults, execution policies, read-only cache, trusted publishing, npm 72-hour read-only mode after credential changes, Dependabot cooldown, npm v12 disabling install scripts [S80].

## 8. Other 2025–2026 changelog entries affecting release pipelines

| Date | Entry | Source |
|---|---|---|
| 2025-03-20 | Notification of upcoming breaking changes (legacy cache service off 2025-04-15; `deployments: write` needed to approve deployments from 2025-04-01) | [S81] |
| 2025-09-29 | New date for enforcement of cache eviction policy (hourly eviction, November 2025) | [S82] |
| 2025-11-06 | New releases for GitHub Actions (10 nested / 50 total reusable workflows) | [S83] |
| 2025-11-20 | Cache size can exceed 10 GB (paid; retention 7 days and size limits as policies) | [S84] |
| 2025-12-04 | workflow_dispatch supports 25 inputs | [S85] |
| 2026-02-19 | Workflow dispatch API returns run IDs (`return_run_details`) | [S86] |
| 2026-02-26 | Non-zipped artifacts (`archive: false`; upload v7 / download v8) | [S36] |
| 2026-03-12 / 2026-04-02 | OIDC custom-property claims `repo_property_*` (preview, then GA) | [S87][S88] |
| 2026-04-23 | Immutable OIDC subject claims (`repo:octo-org@123/octo-repo@456`; default for repos created after 2026-07-15) | [S89] |
| 2026-05-07 | Concurrency `queue: max` (up to 100 queued runs) | [S90] |
| 2026-06-18 | Safer pull_request_target checkout defaults; Control who and what triggers workflows | [S35][S64] |
| 2026-06-26 | Read-only cache for untrusted triggers | [S61] |
| 2026-07-30 | `$/` self-repository action syntax | [S8] |
| 2026-08-27 | Actions retention covers checks, runs, statuses from 2026-10-01 (90-day default) | [S57] |
| 2026-09-03 | `job.workflow_ref`, `job.workflow_sha`, `job.workflow_repository`, `job.workflow_file_path`; `vulnerability-alerts` permission; runner deprecation API | [S59] |
| 2026-09-10 | `cache-mode` GA | [S62] |
| 2026-09-17 | Workflow execution protections GA; Ubuntu 26.04 GA and `ubuntu-latest` migration | [S60][S25] |

## 9. Extra: attestations REST API `bundle_url`

- **Breaking-changes doc, API version 2026-03-10** (released Tue, 10 Mar 2026) [S91]: "Remove the `bundle` property from attestation list responses. The `bundle` field is removed from repo, org, and user attestation list and bulk-list responses. Use `bundle_url` to retrieve the attestation bundle." Affected endpoints: `GET /orgs/{org}/attestations/{subject_digest}`, `GET /repos/{owner}/{repo}/attestations/{subject_digest}`, `GET /users/{username}/attestations/{subject_digest}`, `POST /orgs/{org}/attestations/bulk-list`, `POST /users/{username}/attestations/bulk-list`.
- **Changelog 2026-03-12** "REST API version 2026-03-10 is now available" [S92]: "the first calendar version to include breaking changes"; opt in by setting `X-GitHub-Api-Version` to `2026-03-10`; "Version `2022-11-28` will continue to be fully supported for at least 24 months from today", and unversioned requests "continue to default to `2022-11-28`".
- **Docs** [S46][S47] list `bundle_url: string` with no description; neither docs nor changelog mention snappy or a Content-Type.
- **The compression is evidenced by GitHub's own CLI**: cli/cli PR #10185 "Update `gh attestation` attestation bundle fetching logic" (merged 2025-01-13, shipped in gh v2.66.0) [S93]. Current `pkg/cmd/attestation/api/client.go` fetches `BundleURL` with a plain HTTP client (falling back to the inline `bundle` when the URL is empty), then `snappy.Decode`s the body and `protojson.Unmarshal`s it into a Sigstore v1 `Bundle` (block format, not the framed format). The CLI still pins `X-GitHub-Api-Version: 2022-11-28` for API calls [S94]. So `bundle_url` already existed under 2022-11-28 (since early 2025); 2026-03-10 only removed the inline `bundle`.
- **Content-Type `application/x-snappy`**: not documented in any first-class source found, and `gh` does not inspect the header. Empirical probe against a real attestation is pending on the API rate-limit reset; result will be appended below when available.

## Could not verify

- GhostAction: no first-class source (GHSA, CVE, CISA, GitHub, OpenSSF) exists.
- Attestation retention period: absent from docs and changelog.
- A runner release removing Node 20: none published as of 2026-09-24 (v2.337.0 is latest and still bundles Node 20).
- REST cross-check of tag SHAs (`git/ref/tags`) hit the unauthenticated rate limit; SHAs come from `git ls-remote`, which reads the same refs directly from git.
- Whether the 20 repos above publish immutable releases.
- SPDX/CycloneDX version numbers accepted by the attest actions (docs say only "SPDX or CycloneDX").
- Per-minute arm64 pricing in private repos.
- `application/x-snappy` Content-Type on `bundle_url` (probe pending).
- The Immutable Actions "stop" statement is from GitHub staff in an official community discussion, not a changelog entry.
- Fulcio SAN documentation is a Sigstore (OpenSSF project) source, not GitHub.

## Sources (all accessed 2026-09-24)

- S1 https://docs.github.com/en/actions/reference/security/secure-use
- S2 https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/
- S3 https://docs.github.com/en/organizations/managing-organization-settings/disabling-or-limiting-github-actions-for-your-organization
- S4 https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository
- S5 https://docs.github.com/en/rest/actions/permissions
- S6 https://docs.github.com/en/enterprise-cloud@latest/rest/actions/permissions
- S7 https://github.blog/changelog/2026-02-05-github-actions-early-february-2026-updates/
- S8 https://github.blog/changelog/2026-07-30-reference-same-repository-actions-with-self-repository-syntax/
- S9 https://github.blog/changelog/2022-10-31-dependabot-now-updates-comments-in-github-actions-workflows-referencing-action-versions/
- S10 https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference
- S11 https://github.blog/changelog/2026-07-14-dependabot-version-updates-introduce-default-package-cooldown/
- S12 https://github.com/github/roadmap/issues/592
- S13 https://github.com/github/roadmap/issues/1103
- S14 https://github.com/orgs/community/discussions/181437
- S15 https://github.com/orgs/community/discussions/190621
- S16 https://codeql.github.com/docs/codeql-overview/codeql-changelog/codeql-cli-2.20.6/
- S17 https://github.com/actions/publish-immutable-action
- S18 https://github.blog/changelog/2025-02-12-notice-of-upcoming-deprecations-and-breaking-changes-for-github-actions/
- S19 https://github.com/orgs/actions/packages
- S20 https://github.blog/changelog/2025-10-28-immutable-releases-are-now-generally-available/
- S21 https://github.blog/news-insights/product-news/whats-coming-to-our-github-actions-2026-security-roadmap/
- S22 https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/
- S23 https://github.com/actions/runner/releases and https://raw.githubusercontent.com/actions/runner/main/src/Misc/externals.sh
- S24 https://github.com/actions/runner-images
- S25 https://github.blog/changelog/2026-09-17-ubuntu-26-generally-available-and-latest-migration/
- S26 https://github.blog/changelog/2026-01-22-1-vcpu-linux-runner-now-generally-available-in-github-actions/
- S27 https://github.blog/changelog/2026-05-14-github-actions-upcoming-image-migrations/
- S28 https://github.blog/changelog/2025-08-07-arm64-hosted-runners-for-public-repositories-are-now-generally-available/
- S29 https://github.blog/changelog/2026-01-29-arm64-standard-runners-are-now-available-in-private-repositories/
- S30 https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/
- S31 https://github.blog/changelog/2026-01-01-reduced-pricing-for-github-hosted-runners-usage/
- S32 https://docs.github.com/en/billing/reference/actions-runner-pricing
- S33 https://github.blog/changelog/2026-06-12-github-actions-minimum-version-enforcement-timeline-for-self-hosted-runners/
- S34 https://github.com/actions/checkout (README; releases v5.0.0 and v6.0.0; `action.yml` at v7.0.1)
- S35 https://github.blog/changelog/2026-06-18-safer-pull_request_target-defaults-for-github-actions-checkout/
- S36 https://github.blog/changelog/2026-02-26-github-actions-now-supports-uploading-and-downloading-non-zipped-artifacts/ and https://github.com/actions/upload-artifact/releases
- S37 https://github.com/actions/cache/releases
- S38 https://docs.github.com/en/actions/concepts/security/artifact-attestations
- S39 https://github.com/actions/attest
- S40 https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations
- S41 https://github.com/actions/attest-build-provenance
- S42 https://github.com/actions/attest-sbom
- S43 raw `action.yml` at actions/attest-build-provenance@v4.2.2, actions/attest@v4.2.2, actions/attest-sbom@v4.1.0
- S44 https://cli.github.com/manual/gh_attestation_verify
- S45 https://cli.github.com/manual/gh_release_verify and https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/verifying-the-integrity-of-a-release
- S46 https://docs.github.com/en/rest/repos/attestations
- S47 https://docs.github.com/en/rest/users/attestations
- S48 https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/verify-attestations-offline
- S49 https://docs.github.com/en/actions/how-tos/security-for-github-actions/using-artifact-attestations/enforcing-artifact-attestations-with-a-kubernetes-admission-controller
- S50 https://github.com/github/artifact-attestations-helm-charts
- S51 https://github.com/sigstore/fulcio/blob/main/docs/oidc.md
- S52 https://docs.github.com/en/actions/reference/security/oidc
- S53 https://github.com/sigstore/fulcio/blob/main/docs/oid-info.md
- S54 https://github.blog/changelog/2025-02-18-recent-improvements-to-artifact-attestations/
- S55 https://github.blog/changelog/2025-07-01-manage-artifact-attestations-with-deletion-filtering-and-bulk-actions/
- S56 https://github.blog/changelog/2026-01-20-strengthen-your-supply-chain-with-code-to-cloud-traceability-and-slsa-build-level-3-security/
- S57 https://github.blog/changelog/2026-08-27-actions-retention-will-cover-checks-workflow-runs-and-statuses/
- S58 https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- S59 https://github.blog/changelog/2026-09-03-github-actions-early-september-2026-updates/
- S60 https://github.blog/changelog/2026-09-17-workflow-execution-protections-in-github-actions-generally-available/
- S61 https://github.blog/changelog/2026-06-26-read-only-actions-cache-for-untrusted-triggers/
- S62 https://github.blog/changelog/2026-09-10-control-github-actions-cache-access-with-cache-mode/
- S63 https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments
- S64 https://github.blog/changelog/2026-06-18-control-who-and-what-triggers-github-actions-workflows/
- S65 https://github.blog/changelog/2025-04-22-github-actions-workflow-security-analysis-with-codeql-is-now-generally-available/
- S66 https://github.blog/changelog/2026-09-03-codeql-2-26-4-improves-github-actions-security-detections/
- S67 https://github.com/ossf/scorecard/blob/main/docs/checks.md
- S68 https://github.com/advisories/GHSA-mrrh-fwg8-r2c3
- S69 https://www.cisa.gov/news-events/alerts/2025/03/18/supply-chain-compromise-third-party-github-action-cve-2025-30066
- S70 https://github.com/reviewdog/reviewdog/security/advisories/GHSA-qmg3-hpqr-gqvc
- S71 https://github.com/nrwl/nx/security/advisories/GHSA-cxm3-wv7p-598c
- S72 https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/
- S73 https://github.blog/changelog/2025-11-05-npm-security-update-classic-token-creation-disabled-and-granular-token-changes/
- S74 https://github.blog/changelog/2025-12-09-npm-classic-tokens-revoked-session-based-auth-and-cli-token-management-now-available/
- S75 https://github.blog/security/supply-chain-security/strengthening-supply-chain-security-preparing-for-the-next-malware-campaign/
- S76 https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23
- S77 https://github.com/advisories/GHSA-g7cv-rxg3-hmpx
- S78 https://www.cisa.gov/news-events/alerts/2026/05/28/supply-chain-compromises-impact-nx-console-and-github-repositories
- S79 https://github.blog/security/investigating-unauthorized-access-to-githubs-internal-repositories/
- S80 https://github.blog/security/supply-chain-security/disrupting-supply-chain-attacks-on-npm-and-github-actions/
- S81 https://github.blog/changelog/2025-03-20-notification-of-upcoming-breaking-changes-in-github-actions/
- S82 https://github.blog/changelog/2025-09-29-new-date-for-enforcement-of-cache-eviction-policy/
- S83 https://github.blog/changelog/2025-11-06-new-releases-for-github-actions-november-2025/
- S84 https://github.blog/changelog/2025-11-20-github-actions-cache-size-can-now-exceed-10-gb-per-repository/
- S85 https://github.blog/changelog/2025-12-04-actions-workflow-dispatch-workflows-now-support-25-inputs/
- S86 https://github.blog/changelog/2026-02-19-workflow-dispatch-api-now-returns-run-ids/
- S87 https://github.blog/changelog/2026-03-12-actions-oidc-tokens-now-support-repository-custom-properties/
- S88 https://github.blog/changelog/2026-04-02-github-actions-early-april-2026-updates/
- S89 https://github.blog/changelog/2026-04-23-immutable-subject-claims-for-github-actions-oidc-tokens/
- S90 https://github.blog/changelog/2026-05-07-github-actions-concurrency-groups-now-allow-larger-queues/
- S91 https://docs.github.com/en/rest/about-the-rest-api/breaking-changes?apiVersion=2026-03-10
- S92 https://github.blog/changelog/2026-03-12-rest-api-version-2026-03-10-is-now-available/
- S93 https://github.com/cli/cli/pull/10185
- S94 https://raw.githubusercontent.com/cli/cli/trunk/pkg/cmd/attestation/api/client.go and .../attestation.go
