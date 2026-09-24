<!-- Research digest produced for this repository on 2026-09-24 from primary sources only (specifications, official documentation, changelogs, official repositories). Quotes are verbatim; every source URL and its access date are listed at the end. Items the research could not verify are listed explicitly. -->

# GitHub Releases, tags, rulesets and related protections — state as of 2026-09-24

Research agent: r2-gh-releases. All sources were fetched live on 2026-09-24. Only primary sources were used: GitHub Docs, GitHub Changelog, GitHub's official OpenAPI description (github/rest-api-description), the gh CLI source (cli/cli), and actions/create-github-app-token. Bracketed numbers refer to the source list at the end. Quotes are verbatim.

## 0. Direct answers to the team lead's extra item

- **Repo-level immutable-releases REST endpoints (docs page located and verified).** Page: https://docs.github.com/en/rest/repos/repos, anchors `#check-if-immutable-releases-are-enabled-for-a-repository`, `#enable-immutable-releases`, `#disable-immutable-releases` [11].
  - `GET /repos/{owner}/{repo}/immutable-releases` — "Shows whether immutable releases are enabled or disabled. Also identifies whether immutability is being enforced by the repository owner. The authenticated user must have admin read access to the repository." 200 `{"enabled": bool, "enforced_by_owner": bool}`; 404 when not enabled. Fine-grained: Administration (read) [18].
  - `PUT /repos/{owner}/{repo}/immutable-releases` — "Enables immutable releases for a repository. The authenticated user must have admin access to the repository." 204; 409 Conflict. Administration (write) [18][21].
  - `DELETE /repos/{owner}/{repo}/immutable-releases` — "Disables immutable releases for a repository. The authenticated user must have admin access to the repository." 204; 409. Administration (write) [18].
  - Org level (https://docs.github.com/en/rest/orgs/orgs#get-immutable-releases-settings-for-an-organization) [12][13]: `GET`/`PUT /orgs/{org}/settings/immutable-releases` with body `{"enforced_repositories": "all" | "none" | "selected", "selected_repository_ids": [ ... ]}` (schema: "The policy that controls how immutable releases are enforced in the organization."); `GET`/`PUT /orgs/{org}/settings/immutable-releases/repositories` (`{"selected_repository_ids": [...]}`); `PUT`/`DELETE /orgs/{org}/settings/immutable-releases/repositories/{repository_id}`. Fine-grained: Organization administration (write; GET read) [18].
- **Release attestation docs.** The only GitHub Docs description is the concept page [1]: "creating an immutable release automatically generates a release attestation, which is a cryptographically verifiable record of a release containing the release tag, commit SHA, and release assets." plus the verification how-to [10] (gh release verify / verify-asset). No GitHub Docs or Changelog page states the predicateType URI.
- **Predicate type `https://in-toto.io/attestation/release/v0.2` — NOT verifiable from a GitHub source.** The in-toto spec (third-party repository, not GitHub-owned) currently defines v0.2 at that URI with fields `purl` (required) and `packageId` (v0.1 also exists). GitHub's own API and CLI only use the alias `release` (the REST filter "accepts provenance, sbom, release, or freeform text for custom predicate types." [7]). The gh CLI filters GitHub release attestations on a predicate field named `tag` [8], which is not in the in-toto v0.2 schema, so I cannot confirm GitHub emits the in-toto v0.2 predicate. Treat v0.2 as unverified.
- **Signer identity `https://dotcom.releases.github.com` — VERIFIED from GitHub-owned source.** cli/cli `pkg/cmd/release/shared/attestation.go` builds the policy with a SAN regex `^https://%s\.releases\.github\.com$` where the trust domain defaults to `dotcom`, and the issuer matcher is `.*`; code comment: "SAN must match the GitHub releases domain. No issuer extension (match anything)" [8].
- **Verifying without the gh CLI.** Documented only generically: "Attestations use the Sigstore bundle format, so you can easily verify releases and assets using the GitHub CLI or integrate with any Sigstore-compatible tooling to automate policy enforcement in your CI/CD pipelines." [2]. Reconstructed procedure from the gh CLI source [8] and the REST docs [7][24]:
  1. `GET /repos/{o}/{r}/git/ref/tags/{tag}` and take `object.sha`. Subject digest is `sha1:<sha>` (or `sha256:` when the SHA is 64 hex chars; gh's `DigestAlgForRef` chooses by length).
  2. `GET /repos/{o}/{r}/attestations/{alg}:{sha}?predicate_type=release`. Under the default API version 2022-11-28 the Sigstore bundle is inline in `attestations[].bundle`; under `X-GitHub-Api-Version: 2026-03-10` "The bundle field is removed from repo, org, and user attestation list and bulk-list responses. Use bundle_url to retrieve the attestation bundle." [24]
  3. Verify the bundle with any Sigstore-compatible verifier (cosign, sigstore-go, sigstore-python) with the SAN policy above and the appropriate trust root: "Artifact attestations uses the Sigstore public good instance for public repositories, and GitHub's Sigstore instance for private repositories." [9]
  4. Check that the in-toto statement's predicate `tag` equals your tag and that each asset's SHA-256 appears in the statement `subject` list (gh does exactly this; `gh release verify-asset` "ensures the asset's integrity by validating that the asset's digest matches the subject in the attestation and that the attestation is associated with the release." [8]).
  - Caveats: docs give no cosign command line; a non-gh way to fetch the trusted root is not documented; "Release attestations are not yet supported on GHES and are only available on GitHub.com." [4]; and gh release verify-asset "cannot be used to verify the source code zip file or tarball for a release, since these assets are only created when a download is requested." [10]

## 1. Immutable releases

- **Status:** generally available since 2025-10-28 [2]; public preview 2025-08-26 [3]. Shipped in GitHub Enterprise Server 3.20 (GA 2026-03-17) without attestations [4].
- **What becomes immutable:** the tag and the assets, nothing else. "Only the assets and tag are locked. You can still edit the title and release notes of a published immutable release, and change whether it is marked as a pre-release or as the latest release." [1] Changelog: "Once you publish a release as immutable, its assets can't be added, modified, or deleted." and "Tags for new immutable releases are protected and can't be deleted or moved." [2]
- **When applied:** at publish, and only for releases published after the setting is enabled. "Be aware that immutability will only apply to future releases." [5] "Existing releases remain mutable unless you republish them. Disabling immutability doesn't affect releases created while it was enabled." [2]
- **Drafts:** assets can be uploaded to a draft and the draft then published as immutable. "If you have enabled immutable releases for the repository, creating a draft first allows you to attach all assets before the release becomes immutable." [6] Recommended flow: "Create the release as a draft. Attach all associated assets to the draft release. Publish the draft release." [1]
- **Tag deletion / reuse:** "If you delete the immutable release, you can delete the tag, but you cannot reuse the same tag name." Also: "Even if you delete a repository and create a new one with the same name, you cannot reuse tags that were associated with immutable releases in the original repository." [1]
- **Enable (UI):** repository Settings: "Scroll down to the 'Releases' section, then select Enable release immutability." Organization: Settings → sidebar "Code, planning, and automation" → Repository → General: "In the 'Releases' section of the page, select the No policy dropdown menu, then click either All repositories or Selected repositories." [5]
- **Enable (REST):** see section 0.
- **API surface:** the release object carries `immutable` (boolean; "Whether or not the release is immutable.") [13][17]. The `release` webhook payload schema does not include an `immutable` field [13].

## 2. Release assets

- **Digest field:** since 2025-06-03 GitHub computes SHA-256 at upload; exposed in the Releases UI, REST, GraphQL and gh so you can "verify that downloaded assets haven't been altered since publishing." [14] REST field `digest` is typed "string or null"; example `sha256:2151b604e3429bff440b9fbc03eb3617bc2603cda96c95b9bb05277f9ddba255` [15].
- **Limits:** "Up to 1000 release assets may be associated with a single release. Each file included in a release must be under 2 GiB. There is no limit on the total size of a release, nor bandwidth usage." [16]
- **Latest rule:** "The latest release is the most recent non-prerelease, non-draft release, sorted by the created_at attribute. The created_at attribute is the date of the commit used for the release, and not the date when the release was drafted or published." [17] `make_latest` (string `"true"`, `"false"`, `"legacy"`): "Specifies whether this release should be set as the latest release for the repository. Drafts and prereleases cannot be set as latest. Defaults to true for newly published releases. legacy specifies that the latest release should be determined based on the release creation date and higher semantic version." [17] UI: "If you do not select this option, the latest release label will automatically be assigned based on semantic versioning." [6]
- **Auto-generated notes:** `POST /repos/{o}/{r}/releases/generate-notes` body `tag_name` (required), `target_commitish` (required if the tag does not exist yet), `previous_tag_name`, `configuration_file_path` (defaults to `.github/release.yml` or `.github/release.yaml`); returns `{name, body}`; Contents (write) [17][18]. `generate_release_notes: true` on create does the same inline. Config format [19]:

```yaml
changelog:
  exclude:
    labels: [ignore-for-release]
    authors: [octocat]
  categories:
    - title: Breaking Changes
      labels: [semver-major]
    - title: Other Changes
      labels: ["*"]
```
  "Use * as a catch-all for pull requests that didn't match any of the previous categories." [19]
- **2026-06-30 UI change:** sidebar navigation on release pages and per-asset download counts for users with write access; tarball/zipball downloads are not counted (not in the API either) [20].

## 3. REST API endpoints and permissions

Fine-grained permissions are from the docs' permission tables [18][21]; classic tokens need `repo`.

| Operation | Method and path | Fine-grained permission |
|---|---|---|
| Create release | `POST /repos/{o}/{r}/releases` (201) | Contents (write) |
| Upload asset | `POST https://uploads.github.com/repos/{o}/{r}/releases/{release_id}/assets?name=NAME&label=LABEL` (201; 422 duplicate) | not stated in docs; Contents (write) inferred |
| Update / publish draft | `PATCH /repos/{o}/{r}/releases/{release_id}` with `{"draft": false}` | Contents (write) |
| Get latest | `GET /repos/{o}/{r}/releases/latest` | Contents (read); anonymous for public repos |
| Get by tag | `GET /repos/{o}/{r}/releases/tags/{tag}` | Contents (read) |
| Get by id | `GET /repos/{o}/{r}/releases/{release_id}` | Contents (read) |
| Delete release | `DELETE /repos/{o}/{r}/releases/{release_id}` (204) | Contents (write) |
| List assets | `GET /repos/{o}/{r}/releases/{release_id}/assets` | Contents (read) |
| Asset get / update / delete | `GET` / `PATCH` (`name`, `label`, `state`) / `DELETE /repos/{o}/{r}/releases/assets/{asset_id}` | read / write / write |
| Generate notes | `POST /repos/{o}/{r}/releases/generate-notes` | Contents (write) |
| List attestations | `GET /repos/{o}/{r}/attestations/{subject_digest}` (`predicate_type`, `per_page` ≤ 100, `before`, `after`) | Attestations (read) |
| Store attestation | `POST /repos/{o}/{r}/attestations` body `{"bundle": {"mediaType", "verificationMaterial", "dsseEnvelope"}}` | Attestations (write) |
| Org / user attestations | `GET /orgs/{org}/attestations/{subject_digest}`; `POST /orgs/{org}/attestations/bulk-list` (`subject_digests[]`, `predicate_type`); `POST /orgs/{org}/attestations/delete-request`; `DELETE /orgs/{org}/attestations/digest/{subject_digest}`; `DELETE /orgs/{org}/attestations/{attestation_id}`; `GET /orgs/{org}/attestations/repositories`; identical shapes under `/users/{username}` | Attestations (read); deletes need write |

- **Create body** [17]: `tag_name` (required); `target_commitish` — "Specifies the commitish value that determines where the Git tag is created from. Can be any branch or commit SHA. Unused if the Git tag already exists. Default: the repository's default branch."; `name`; `body`; `draft` (default false); `prerelease` (default false); `discussion_category_name`; `generate_release_notes` (default false); `make_latest`. "Users with push access to the repository can create a release."

```json
{"tag_name":"v1.2.3","target_commitish":"main","name":"v1.2.3","body":"...","draft":true,"prerelease":false,"generate_release_notes":true,"make_latest":"true"}
```
- **Upload rules** [15]: "Use the required Content-Type header to provide the media type of the asset"; "GitHub expects the asset data in its raw binary form, rather than JSON"; "You need to use an HTTP client which supports SNI"; "If you upload an asset with the same filename as another uploaded asset, you'll receive an error and must delete the old file before you can re-upload the new asset."; a 502 "may leave an empty asset with a state of starter. It can be safely deleted."; "GitHub renames asset filenames that have special characters, non-alphanumeric characters, and leading or trailing periods." The docs page has no fine-grained-permission block for this endpoint (confirmed in the page source) and it is absent from both permission tables.
- **Attestation list docs note** [7]: "In order to offer meaningful security benefits, an attestation's signature and timestamps must be cryptographically verified, and the identity of the attestation signer must be validated." `subject_digest` "should be set to the attestation's subject's SHA256 digest, in the form sha256:HEX_DIGEST."
- **API versioning:** version 2026-03-10 (released 2026-03-10, announced 2026-03-12) is "the first calendar version to include breaking changes"; 2022-11-28 remains the default and "will continue to be fully supported for at least 24 months" [23]. Relevant breaking changes [24]: attestation list responses lose `bundle` (use `bundle_url`); `POST /repos/{o}/{r}/actions/workflows/{workflow_id}/dispatches` — "Removes the return_run_details parameter. The endpoint now always returns 200 with the workflow run details in the response body."; repository objects lose `has_downloads`. No release, ruleset or actions-permissions endpoint otherwise changed.

## 4. Tags and tag rulesets

- **Tag creation on release:** docs only say "Releases are based on Git tags, which mark a specific point in your repository's history. A tag date may be different than a release date since they can be created at different times." [16] plus the `target_commitish` sentence above. No GitHub Docs page states whether the tag is lightweight or annotated, who the tagger is, or whether it is signed (see Unverified 1). GitHub verifies signed annotated tags and shows the status on the Tags page: "Next to your tag description, there is a box that shows whether your tag signature is verified, partially verified, or unverified." [25] Design implication: push a signed annotated tag yourself, then create the release against the existing tag ("Unused if the Git tag already exists.").
- **Draft + new tag:** not documented when the tag is created. The gh CLI looks up drafts "by its pending tag name" via GraphQL "since REST doesn't have this ability" [8], implying the tag does not exist until publish (inference; Unverified 7).
- **Legacy tag protection rules are removed:** sunset 2024-08-30; "All REST and GraphQL API endpoints will be deprecated"; "If no action is taken before the sunset date, GitHub will migrate all existing tag protections into a corresponding ruleset." [26]
- **Ruleset targets:** `target` ∈ `branch`, `tag`, `push` [13][28]. Rules the docs scope to "branches or tags" [27]: Restrict creations ("only users with bypass permissions can create branches or tags whose name matches the pattern you specify."), Restrict updates, Restrict deletions ("This rule is selected by default."), Require linear history, Block force pushes ("This rule is enabled by default."), Require status checks ("a branch or tag targeted by your ruleset"). Require signed commits: "contributors and bots can only push commits that have been signed and verified" [27]; REST: "Commits pushed to matching refs must have verified signatures." [28] Nothing says the tag object's own signature is checked (Unverified 5).
- **REST rule types** [28]: `creation`, `update`, `deletion`, `required_linear_history`, `merge_queue`, `required_deployments`, `required_signatures`, `pull_request`, `required_status_checks`, `non_fast_forward`, `commit_message_pattern`, `commit_author_email_pattern`, `committer_email_pattern`, `branch_name_pattern`, `tag_name_pattern`, `workflows`, `code_scanning`, `code_quality`, `code_coverage`, `copilot_code_review`, `license_compliance_scanning`, `file_path_restriction`, `max_file_path_length`, `file_extension_restriction`, `max_file_size`. Pattern rules take `operator` ∈ `starts_with`, `ends_with`, `contains`, `regex` plus `pattern` (and `negate`).
- **Bypass actors** [13][28]: `actor_type` ∈ `Integration`, `OrganizationAdmin`, `RepositoryRole`, `Team`, `DeployKey`, `User`; `bypass_mode` ∈ `always`, `pull_request`, `exempt`. Schema text: "pull_request means that an actor can only bypass rules on pull requests. pull_request is not applicable for the DeployKey actor type. Also, pull_request is only applicable to branch rulesets. When bypass_mode is exempt, rules will not be run for that actor and a bypass audit entry will not be created." `conditions.ref_name.include` "Also accepts ~DEFAULT_BRANCH to include the default branch or ~ALL to include all branches."
- **Create ruleset:** `POST /repos/{owner}/{repo}/rulesets` — Administration (write) [21]; `enforcement` ∈ `disabled`, `active`, `evaluate`. Tag example constructed from the documented schema (the docs' own example targets branches):

```json
{
  "name": "release tags",
  "target": "tag",
  "enforcement": "active",
  "bypass_actors": [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}],
  "conditions": {"ref_name": {"include": ["refs/tags/v*"], "exclude": []}},
  "rules": [
    {"type": "creation"}, {"type": "update"}, {"type": "deletion"},
    {"type": "non_fast_forward"}, {"type": "required_signatures"},
    {"type": "tag_name_pattern", "parameters": {"operator": "regex", "pattern": "^v[0-9]+\\.[0-9]+\\.[0-9]+$"}}
  ]
}
```
- **2025–2026 ruleset changes:** ruleset history, import and export GA (2025-02-13) [47]; convert branch protection rules to rulesets in one click (2026-08-11) [29]; push-rule path exceptions, public preview (2026-08-25) [30]; required reviewer rule GA (2026-02-17) [31]; restrict who can dismiss reviews (2026-07-07) [32].

## 5. Workflow triggers

- **`release` event** [33]: activity types `published`, `unpublished`, `created`, `edited`, `deleted`, `prereleased`, `released`; `GITHUB_SHA` = "Last commit in the tagged release"; `GITHUB_REF` = "Tag ref of release refs/tags/<tag_name>". Docs notes: "Workflows are not triggered for the created, edited, or deleted activity types for draft releases. When you create your release through the GitHub UI, your release may automatically be saved as a draft." and "The prereleased type will not trigger for pre-releases published from draft releases, but the published type will trigger. If you want a workflow to run when stable and pre-releases publish, subscribe to published instead of released and prereleased."
- **Webhook definitions of each action** (OpenAPI x-webhooks) [13]: `published` — "A release, pre-release, or draft of a release was published."; `created` — "A draft was saved, or a release or pre-release was published without previously being saved as a draft."; `released` — "A release was published, or a pre-release was changed to a release."; `prereleased` — "A release was created and identified as a pre-release. A pre-release is a release that is not ready for production and may be unstable."; `unpublished` — "A release or pre-release was unpublished."; `deleted` — "A release, pre-release, or draft release was deleted."; `edited` — "The details of a release, pre-release, or draft release were edited." So draft → publish fires `published` (and `released` for a non-prerelease), never `created`/`prereleased`.
- **`push` with tags** [34]: "If you define only tags/tags-ignore or only branches/branches-ignore, the workflow won't run for events affecting the undefined Git ref." Example `tags: [v2, 'v1.*']`. Also: "Events will not be created for tags when more than three tags are pushed at once." [33]
- **`workflow_dispatch` inputs** [34]: types `string`, `choice`, `boolean`, `number`, `environment`; keys `required`, `default`, `options`; "The maximum number of top-level properties for inputs is 25."; "The maximum payload for inputs is 65,535 characters."; read via `${{ inputs.<name> }}`.
- **GITHUB_TOKEN does not trigger workflows** [35]: "When you use the repository's GITHUB_TOKEN to perform tasks, events triggered by the GITHUB_TOKEN will not create a new workflow run, with the following exceptions: workflow_dispatch and repository_dispatch events always create workflow runs." Documented workarounds: a GitHub App installation access token or a personal access token stored as a secret. Official action [36]: `actions/create-github-app-token@v3` with `client-id`, `private-key`, `owner`, `repositories`, `permission-contents: write`; "An installation access token expires after 1 hour." and it is revoked after the job unless `skip-token-revoke` is set.
- **New in 2026:** workflow execution protections (2026-06-18) under Settings → Actions → Policies, with actor rules ("individual users, repository roles ... GitHub Apps, Copilot, and Dependabot") and event rules ("such as push, pull_request, pull_request_target, and workflow_dispatch"); GitHub "will enforce a default policy blocking the pull_request_target event in public repositories on November 2, 2026." [37][38]

## 6. Signature verification display

- "If a commit or tag has a GPG, SSH, or S/MIME signature that is cryptographically verifiable, GitHub marks the commit or tag 'Verified' or 'Partially verified.'" Default statuses: Verified ("The commit is signed and the signature was successfully verified."), Unverified ("The commit is signed but the signature could not be verified."), no status ("The commit is not signed."). "If a commit or tag has a bot signature that is cryptographically verifiable, GitHub marks the commit or tag as verified." "GitHub will automatically use GPG to sign commits you make using the web interface." "SSH signature verification is available in Git 2.34 or later." [39] Sigstore/gitsign is not mentioned anywhere in these pages (Unverified 6).
- **Vigilant mode** [40]: Settings → SSH and GPG keys → Vigilant mode → "Flag unsigned commits as unverified". Verified = "The commit is signed, the signature was successfully verified, and the committer is the only author who has enabled vigilant mode."; Partially verified = signed and verified "but the commit has an author who: a) is not the committer and b) has enabled vigilant mode."; unsigned commits by vigilant-mode users show Unverified.
- **Tag status check** [25]: repository → Releases → Tags → box next to the tag description; click Verified / Partially verified / Unverified for details.
- **Add SSH signing key (UI)** [41]: Settings → Access → SSH and GPG keys → New SSH key; "Select the type of key, either authentication or signing."; "If you want to use the same SSH key for both authentication and signing, you need to upload it twice." CLI: `gh ssh-key add ~/.ssh/id_ed25519.pub --type signing`.
- **REST** [42][18]: `GET /user/ssh_signing_keys` (classic scope `read:ssh_signing_key`); `POST /user/ssh_signing_keys` body `{"title": "...", "key": "ssh-ed25519 ..."}` (`write:ssh_signing_key`); `GET /user/ssh_signing_keys/{ssh_signing_key_id}` (`read:ssh_signing_key`); `DELETE /user/ssh_signing_keys/{ssh_signing_key_id}` (`admin:ssh_signing_key`); `GET /users/{username}/ssh_signing_keys` ("This operation is accessible by anyone"). Fine-grained user permission "SSH signing keys" (read for GETs, write for POST/DELETE).

## 7. Repository hardening settings via REST

Repository endpoints need Administration (write); their GETs need Administration (read) [18].

| Setting | Endpoint and JSON body |
|---|---|
| Actions enablement, allowed actions, SHA pinning | `PUT /repos/{o}/{r}/actions/permissions` `{"enabled": true, "allowed_actions": "selected", "sha_pinning_required": true}` — `allowed_actions` ∈ `all`, `local_only`, `selected`; `sha_pinning_required`: "Whether actions must be pinned to a full-length commit SHA." [43][13] |
| Allow-list with blocking | `PUT /repos/{o}/{r}/actions/permissions/selected-actions` `{"github_owned_allowed": true, "verified_allowed": false, "patterns_allowed": ["space-org/*", "!space-org/action@*"]}` — "Prefix an entry with ! to block a specific action or version. The blocklist is evaluated last, overriding any other policy." [43][44][45] |
| GITHUB_TOKEN default | `PUT /repos/{o}/{r}/actions/permissions/workflow` `{"default_workflow_permissions": "read", "can_approve_pull_request_reviews": false}` [43] |
| Org equivalents | `PUT /orgs/{org}/actions/permissions` `{"enabled_repositories": "all" | "none" | "selected", "allowed_actions": "selected", "sha_pinning_required": true}`; `PUT /orgs/{org}/actions/permissions/selected-actions`; `PUT /orgs/{org}/actions/permissions/workflow` — `admin:org` / Organization administration (write) [43] |
| Other repo Actions settings | `PUT .../actions/permissions/access` `{"access_level": "none" | "user" | "organization"}` (private repos); `PUT .../actions/permissions/artifact-and-log-retention` `{"days": 90}`; `PUT .../actions/permissions/fork-pr-workflows-private-repos` `{"run_workflows_from_fork_pull_requests": false, "send_write_tokens_to_workflows": false, "send_secrets_and_variables": false, "require_approval_for_fork_pr_workflows": true}`; `PUT .../actions/permissions/fork-pr-contributor-approval` `{"approval_policy": "all_external_contributors"}` [43] |
| Web sign-off and security features | `PATCH /repos/{o}/{r}` `{"web_commit_signoff_required": true, "security_and_analysis": {"advanced_security": {"status": "enabled"}, "secret_scanning": {"status": "enabled"}, "secret_scanning_push_protection": {"status": "enabled"}, "dependabot_security_updates": {"status": "enabled"}, "secret_scanning_ai_detection": {"status": "enabled"}}, "allow_forking": false, "delete_branch_on_merge": true}` [11] |
| Dependabot alerts | `PUT` / `DELETE /repos/{o}/{r}/vulnerability-alerts` (204); `GET` returns 204 enabled / 404 disabled ("Enables dependency alerts and the dependency graph for a repository") [11] |
| Dependabot security updates | `PUT` / `DELETE /repos/{o}/{r}/automated-security-fixes` (204); `GET` → `{"enabled": bool, "paused": bool}` [11] |
| Private vulnerability reporting | `PUT` / `DELETE /repos/{o}/{r}/private-vulnerability-reporting` (204); `GET` → `{"enabled": bool}` [11] |

- **SHA pinning UI** [45]: Settings → Actions → General → Actions permissions → "Require actions to be pinned to a full-length commit SHA": "all actions must be pinned to a full-length commit SHA to be used. This includes actions from your organization and actions authored by GitHub. Reusable workflows can still be referenced by tag." Introduced 2025-08-15 at enterprise, organization and repository levels [44].
- **OIDC subject claims** [46]: since 2026-04-23 the default `sub` claim can embed owner and repository IDs (example `repo:octocat@123456/my-repo@456789:ref:refs/heads/main`); automatic for repositories created after 2026-07-15, opt-in for existing ones; cloud trust policies must be updated.

## 8. Other 2025–2026 changelog entries a release-engineering design must account for

Fetched and verified:
- 2025-02-13 — Repositories: Ruleset history, import and export are generally available — https://github.blog/changelog/2025-02-13-repositories-ruleset-history-import-and-export-are-generally-available/
- 2025-06-03 — Releases now expose digests for release assets — https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/
- 2025-07-01 — Manage artifact attestations with deletion, filtering, and bulk actions — https://github.blog/changelog/2025-07-01-manage-artifact-attestations-with-deletion-filtering-and-bulk-actions/
- 2025-08-15 — GitHub Actions policy now supports blocking and SHA pinning actions — https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/
- 2025-08-26 — Releases now support immutability in public preview — https://github.blog/changelog/2025-08-26-releases-now-support-immutability-in-public-preview/
- 2025-10-28 — Immutable releases are now generally available — https://github.blog/changelog/2025-10-28-immutable-releases-are-now-generally-available/
- 2026-01-20 — Strengthen your supply chain with code-to-cloud traceability and SLSA Build Level 3 security (artifact metadata REST APIs; attest-build-provenance can "automatically create storage records when you publish artifacts") — https://github.blog/changelog/2026-01-20-strengthen-your-supply-chain-with-code-to-cloud-traceability-and-slsa-build-level-3-security/
- 2026-02-17 — Required reviewer rule is now generally available — https://github.blog/changelog/2026-02-17-required-reviewer-rule-is-now-generally-available/
- 2026-03-12 — REST API version 2026-03-10 is now available — https://github.blog/changelog/2026-03-12-rest-api-version-2026-03-10-is-now-available/
- 2026-03-17 — GitHub Enterprise Server 3.20 is now generally available (immutable releases on GHES; "Release attestations are not yet supported on GHES") — https://github.blog/changelog/2026-03-17-github-enterprise-server-3-20-is-now-generally-available/
- 2026-04-23 — Immutable subject claims for GitHub Actions OIDC tokens — https://github.blog/changelog/2026-04-23-immutable-subject-claims-for-github-actions-oidc-tokens/
- 2026-06-18 — Control who and what triggers GitHub Actions workflows — https://github.blog/changelog/2026-06-18-control-who-and-what-triggers-github-actions-workflows/
- 2026-06-30 — Releases: Sidebar navigation and per-asset download counts — https://github.blog/changelog/2026-06-30-releases-sidebar-navigation-and-per-asset-download-counts/
- 2026-07-07 — Restrict who can dismiss reviews in rulesets — https://github.blog/changelog/2026-07-07-restrict-who-can-dismiss-reviews-in-rulesets/
- 2026-08-11 — Automatically migrate branch protection rules to repository rulesets — https://github.blog/changelog/2026-08-11-automatically-migrate-branch-protection-rules-to-repository-rulesets/
- 2026-08-25 — Push rules in rulesets now support path exceptions (public preview) — https://github.blog/changelog/2026-08-25-push-rules-in-rulesets-now-support-path-exceptions/
- Context (2024): 2024-05-29 — Sunset Notice - Tag Protections — https://github.blog/changelog/2024-05-29-sunset-notice-tag-protections/

Seen only in the changelog index (titles/dates, not individually fetched): 2025-06-16 Organization rulesets now available for GitHub Team plans; 2026-02-24 GitHub Enterprise Server 3.20 release candidate is available; 2026-04-16 Rule insights dashboard and unified filter bar; 2026-08-12 Rule insights for organizations in public preview; 2026-08-25 Rule insights dashboard generally available.

## Could not verify

1. Whether a tag created by the release UI/API is lightweight or annotated, who the tagger is, and whether it is signed. No GitHub Docs page states this.
2. The exact predicateType URI GitHub uses for release attestations. GitHub sources only use the alias `release`; the in-toto v0.2 URI is third-party and its schema (`purl`, `packageId`) lacks the `tag` field the gh CLI relies on.
3. The fine-grained permission for the upload-asset endpoint (no permissions block on the docs page; absent from the PAT and GitHub App permission tables). Contents (write) is an inference.
4. Whether assets uploaded before June 2025 have `null` digests (schema allows null; changelog silent).
5. Whether "Require signed commits" on a tag ruleset checks the tag object's signature (docs describe commit signatures only).
6. Whether Sigstore/gitsign signatures ever display as Verified (docs list only GPG, SSH and S/MIME).
7. When the tag is created for a draft release (publish time is inferred from the gh CLI code, not documented).
8. A documented non-gh verification command (cosign or similar) for release attestations, and a non-gh way to fetch the trusted root.
9. Live checks against a real immutable release (predicate contents, signer certificate) were blocked by the unauthenticated API rate limit.

## Sources (all accessed 2026-09-24)

1. https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases
2. https://github.blog/changelog/2025-10-28-immutable-releases-are-now-generally-available/ (2025-10-28)
3. https://github.blog/changelog/2025-08-26-releases-now-support-immutability-in-public-preview/ (2025-08-26)
4. https://github.blog/changelog/2026-03-17-github-enterprise-server-3-20-is-now-generally-available/ (2026-03-17)
5. https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes
6. https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
7. https://docs.github.com/en/rest/repos/attestations
8. https://raw.githubusercontent.com/cli/cli/trunk/pkg/cmd/release/verify/verify.go ; https://raw.githubusercontent.com/cli/cli/trunk/pkg/cmd/release/shared/attestation.go ; https://raw.githubusercontent.com/cli/cli/trunk/pkg/cmd/release/shared/fetch.go ; https://raw.githubusercontent.com/cli/cli/trunk/pkg/cmd/release/verify-asset/verify_asset.go
9. https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/verify-attestations-offline
10. https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/verify-release-integrity
11. https://docs.github.com/en/rest/repos/repos
12. https://docs.github.com/en/rest/orgs/orgs
13. https://raw.githubusercontent.com/github/rest-api-description/main/descriptions/api.github.com/api.github.com.json (OpenAPI description version 1.1.4; `x-webhooks` and component schemas)
14. https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/ (2025-06-03)
15. https://docs.github.com/en/rest/releases/assets
16. https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
17. https://docs.github.com/en/rest/releases/releases
18. https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens
19. https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes
20. https://github.blog/changelog/2026-06-30-releases-sidebar-navigation-and-per-asset-download-counts/ (2026-06-30)
21. https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps
22. https://docs.github.com/en/rest/users/attestations ; https://docs.github.com/en/rest/orgs/attestations
23. https://github.blog/changelog/2026-03-12-rest-api-version-2026-03-10-is-now-available/ (2026-03-12)
24. https://docs.github.com/en/rest/about-the-rest-api/breaking-changes?apiVersion=2026-03-10
25. https://docs.github.com/en/authentication/troubleshooting-commit-signature-verification/checking-your-commit-and-tag-signature-verification-status
26. https://github.blog/changelog/2024-05-29-sunset-notice-tag-protections/ (2024-05-29)
27. https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
28. https://docs.github.com/en/rest/repos/rules
29. https://github.blog/changelog/2026-08-11-automatically-migrate-branch-protection-rules-to-repository-rulesets/ (2026-08-11)
30. https://github.blog/changelog/2026-08-25-push-rules-in-rulesets-now-support-path-exceptions/ (2026-08-25)
31. https://github.blog/changelog/2026-02-17-required-reviewer-rule-is-now-generally-available/ (2026-02-17)
32. https://github.blog/changelog/2026-07-07-restrict-who-can-dismiss-reviews-in-rulesets/ (2026-07-07)
33. https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
34. https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
35. https://docs.github.com/en/actions/how-tos/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow
36. https://github.com/actions/create-github-app-token
37. https://github.blog/changelog/2026-06-18-control-who-and-what-triggers-github-actions-workflows/ (2026-06-18)
38. https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/actions-policies/workflow-execution-protections
39. https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification
40. https://docs.github.com/en/authentication/managing-commit-signature-verification/displaying-verification-statuses-for-all-of-your-commits
41. https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account
42. https://docs.github.com/en/rest/users/ssh-signing-keys
43. https://docs.github.com/en/rest/actions/permissions
44. https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/ (2025-08-15)
45. https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository
46. https://github.blog/changelog/2026-04-23-immutable-subject-claims-for-github-actions-oidc-tokens/ (2026-04-23)
47. https://github.blog/changelog/2025-02-13-repositories-ruleset-history-import-and-export-are-generally-available/ (2025-02-13)
48. https://github.blog/changelog/2025-07-01-manage-artifact-attestations-with-deletion-filtering-and-bulk-actions/ (2025-07-01)
49. https://github.blog/changelog/2026-01-20-strengthen-your-supply-chain-with-code-to-cloud-traceability-and-slsa-build-level-3-security/ (2026-01-20)

Also consulted: https://cli.github.com/manual/gh_release_verify ; https://cli.github.com/manual/gh_release_verify-asset ; https://github.com/cli/cli/releases/tag/v2.81.0 (release verify commands shipped 2025-10-01) ; https://docs.github.com/en/actions/concepts/about-actions-policies ; https://github.com/in-toto/attestation/blob/main/spec/predicates/release.md (third-party; v0.2 current).
