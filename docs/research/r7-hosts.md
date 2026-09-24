<!-- Research digest produced for this repository on 2026-09-24 from primary sources only (specifications, official documentation, changelogs, official repositories). Quotes are verbatim; every source URL and its access date are listed at the end. Items the research could not verify are listed explicitly. -->

# Releases on git hosts other than GitHub: host-agnostic core and per-host adapters

Research agent: r7-hosts. Access date for every source: **2026-09-24**. The GitLab YAML reference, git config documentation, sourcehut docs, Bitbucket OpenAPI spec and Forgejo/Gitea sources were downloaded with curl and grepped, so those quotes are exact; other quotes come from live fetches of the rendered pages. Source numbers refer to the list at the end.

## 1. GitLab (docs.gitlab.com, current stream; history notes run to GitLab 19.1)

**Release object.** A release is a first-class object tied to a tag. "Releases combine code, binaries, documentation, and release notes into a complete snapshot of your project. When a release is created, GitLab automatically tags your code, archives a snapshot, and generates audit-ready evidence." [1] Existing tags can be used: "Select an existing Git tag. Selecting an existing tag that is already associated with a release results in a validation error." [1] Delete: "When you delete a release, its assets are also deleted. However, the associated Git tag is not deleted." [1] Permissions: "Users with the Developer, Maintainer, or Owner role have write access to the project releases and assets. If a release is associated with a protected tag, the user must be allowed to create the protected tag too." [1]

**Assets.** Source archives are generated automatically in zip, tar.gz, tar.bz2 and tar; other assets are *links* (http, https, ftp) with optional permanent paths of the form `/-/releases/:release/downloads:filepath` and a latest permalink `/-/releases/permalink/latest/downloads:filepath`. [2] Binaries themselves go to the generic package registry: "Use the generic packages repository to publish and manage generic files, such as release binaries, in your project's package registry." Endpoint `PUT /projects/:id/packages/generic/:package_name/:package_version/:file_name`. [9] The `glab` CLI ties the two together: positional files are uploaded as release assets, and `--use-package-registry` "uploads assets to the project's generic package registry" (env `GITLAB_RELEASE_ASSETS_USE_PACKAGE_REGISTRY`, default package name `release-assets`). [5][6]

**`release:` keyword (verbatim from the YAML reference source).** "Use `release` to create a release." "The release job must have access to the `glab` CLI, which must be in the `$PATH`." Image: `registry.gitlab.com/gitlab-org/cli:latest`. "Release jobs must include the `script` keyword." "A release is created only if the job's main script succeeds." "If the release already exists, it is not updated and the job with the `release` keyword fails." "The `release` keyword uses the `glab` CLI and creates the release with `glab release create`. The release is authenticated with the `CI_JOB_TOKEN` by default." Subkeys: `tag_name`, `tag_message`, `name`, `description`, `ref`, `milestones`, `released_at`, `assets:links`. On `tag_name`: "If the tag does not exist in the project yet, it is created at the same time as the release. New tags use the SHA associated with the pipeline." On `tag_message`: "If omitted, a lightweight tag is created." The canonical example uses `rules: - if: $CI_COMMIT_TAG`. [3]

Canonical example from the reference [3]:

```yaml
release_job:
  stage: release
  image: registry.gitlab.com/gitlab-org/cli:latest
  rules:
    - if: $CI_COMMIT_TAG                  # Run this job when a tag is created manually
  script:
    - echo "Running the release job."
  release:
    tag_name: $CI_COMMIT_TAG
    name: 'Release $CI_COMMIT_TAG'
    description: 'Release created using the CLI.'
```

**release-cli.** Page title is "GitLab Release CLI tool (deprecated)": "This feature was deprecated in GitLab 18.0 and is planned for removal in 20.0. Use the GitLab CLI instead." [4] The releases page adds: "You must use GitLab CLI tool v1.58.0 or higher." [1]

**REST API.** `POST /projects/:id/releases` with `tag_name` (required), `ref` (used when the tag does not exist), `name`, `description`, `milestones`, `released_at`, `assets.links[]` with `name`, `url`, `direct_asset_path`, `link_type` in `other`, `runbook`, `image`, `package`. `PUT` and `DELETE /projects/:id/releases/:tag_name` exist (Developer role). Direct download: `GET /projects/:id/releases/:tag_name/downloads/:direct_asset_path`. Evidence: `POST /projects/:id/releases/:tag_name/evidence` (Premium/Ultimate). [7] Links API: `POST /projects/:id/releases/:tag_name/assets/links`. [8]

**Release evidence.** "Each time a release is created, GitLab takes a snapshot of data that's related to it. This data is saved in a JSON file and called _release evidence_." "You can collect release evidence multiple times for one release." JSON fields shown: `id`, `tag_name`, `name`, `project`, `created_at`, `description`, `milestones`, `packages`, `report_artifacts`. Historical releases: "Due to being released in the past, release evidence is not available." [20][1]

**Protected tags.** Purpose: "Allow control over who has permission to create tags" and "Prevent accidental update or deletion once created." Wildcards `v*`, `*-deploy`, `*`. "Allowed to create" accepts roles, deploy keys, "No one", and (Premium/Ultimate) users and groups. "Protected tags can only be deleted by using GitLab either from the UI or API." [10] Tags page: "To prevent users from removing a tag with `git push`, create a push rule." [11]

**Tag signature verification.** "GitLab verifies signatures on commits and tags. The following signing methods are supported: SSH key, GPG key, X.509 certificate". [12] SSH page: "If successful, GitLab displays a **Verified** label on the commit or tag." History block (verbatim from source): "Introduced in GitLab 18.3 with a feature flag named `render_ssh_signed_tags_verification_status`. Disabled by default." "Enabled on GitLab.com, GitLab Self-Managed, and GitLab Dedicated in GitLab 18.11." "Generally available in GitLab 19.1." [13] Tags page: "Annotated tags contain metadata, can be signed for verification purposes, and can't be changed." [11]

**OIDC and keyless signing.** "ID tokens are JSON web tokens (JWT) generated by GitLab CI/CD. CI/CD jobs can use ID tokens for OIDC authentication with third-party services." Claims include `ref`, `ref_type` (branch or tag), `ref_protected`, `project_path`, `sha`, `pipeline_source`, `runner_environment`, `ci_config_sha`, `ci_config_ref_uri`. [14] YAML example in the reference: `SIGSTORE_ID_TOKEN: aud: sigstore`. [3] Sigstore page: "GitLab ID tokens can be used by Cosign for keyless signing. The token must have `sigstore` set as the `aud` claim", picked up automatically from `SIGSTORE_ID_TOKEN`; verify with `cosign verify --certificate-identity ... --certificate-oidc-issuer`; blobs via `cosign sign-blob` producing a bundle; Cosign >= 2.0.1. [15]

**Provenance.** `RUNNER_GENERATE_ARTIFACTS_METADATA=true`: "Artifact provenance metadata is generated in the in-toto v0.1 Statement format. It contains a provenance predicate generated in the SLSA 1.0 Provenance format." Filename `{ARTIFACT_NAME}-metadata.json`. [16] SLSA overview: level 2 via "a SLSA level 2 compliant provenance statement that can be automatically generated for all build artifacts produced by the GitLab Runner", signed by the GitLab SLSA CI/CD component. [17] Level 3 page (verbatim from source): "Tier: Ultimate", "Offering: GitLab.com", "Status: Experiment"; "Introduced in GitLab 18.3 with a feature flag named `slsa_provenance_statement`. Disabled by default."; prerequisites: project public ("to prevent accidental disclosure of information to Rekor"), `build` stage; `ATTEST_BUILD_ARTIFACTS: true`; "The artifact must not exceed 100 MB."; verify with `glab attestation verify`. [18] Attestations API returns Sigstore bundles; "Introduced in GitLab 18.5 with a feature flag". [19]

**Immutability.** No immutable-release feature exists in the docs. Releases are updatable and deletable via API by Developers; only the `release:` keyword refuses to touch an existing release. The "immutable tags" feature is container-registry only. [23] Tag immutability comes from protected tags plus push rules.

**Tag trigger.** `CI_COMMIT_TAG`: "The commit tag name. Available only in pipelines for tags." `CI_COMMIT_TAG_MESSAGE`: "The commit tag message. Available only in pipelines for tags." [21] Rules doc: "`if: $CI_COMMIT_TAG`: If changes are pushed for a tag." [22]

## 2. Gitea (docs 1.28-dev; API 1.27) and Forgejo (docs v16.0)

**Release object and API (shared lineage).** Gitea: `POST /repos/{owner}/{repo}/releases` with `tag_name` (required), `target_commitish`, `name`, `body`, `draft`, `prerelease`, `tag_message`; 201/404/409/422. [24] Attachments: `POST /repos/{owner}/{repo}/releases/{id}/assets`, query `name`, body `attachment` (binary; `application/octet-stream` or `multipart/form-data`); 413 on oversize. [25] Tags: `POST /repos/{owner}/{repo}/tags` with `tag_name`, `target`, `message`. [26] Forgejo: "Releases are a feature in Forgejo, independent of Git, that allows you to attach files and release notes along with the source code at the time, and share it in Forgejo, linking to a Git tag." Assets are attached files or external links; `.zip`/`.tar.gz` source archives are generated; drafts and pre-releases exist. [36] Forgejo API location: `/api/swagger`, `/swagger.v1.json`, header `Authorization: token ...`. [42]

**Protected tags.** Gitea: "Protected tags allow control over who has permission to create or update Git tags." Glob (`v*`, `v[0-9]`, `*-release`) or regex in slashes (`/\Av\d+\.\d+\.\d+\z/`). [28] API: `POST /repos/{owner}/{repo}/tag_protections` with `name_pattern`, `whitelist_usernames`, `whitelist_teams`. [27] Forgejo: "If you leave these fields empty, no one is allowed to create or modify this tag." [37]

**Actions compatibility.** Gitea: "Even though Gitea Actions is designed to be compatible with GitHub Actions, there are some differences between them." `uses: actions/checkout@v4` resolves via `[actions].DEFAULT_ACTIONS_URL` (now `github`; "Previously (Pre 1.21.0), `[actions].DEFAULT_ACTIONS_URL` defaulted to `https://gitea.com`"); absolute URLs allowed. `permissions` is supported but "GitHub-only scopes such as `statuses`, `checks`, `deployments`, `id-token`, `security-events`, and `pages` are not supported, while Gitea-specific scopes such as `code`, `releases`, `wiki`, and `projects` are available." Package publishing with `GITEA_TOKEN` "is not implemented in Gitea Actions now." [30] Supported events include `push`, `create`, `release` (`published`, `edited`), `registry_package`, `workflow_run`. [31] Workflows live in `.gitea/workflows/`. [32] Runner: "The Gitea Runner executes the jobs of Gitea Actions. It polls a Gitea instance for queued jobs". [33]

Forgejo: "Forgejo Actions is designed to be familiar to users of GitHub Actions, but it is **not designed to be compatible**." Ignored subkeys: `permissions`, `continue-on-error`. [39] Reference: "A relative `Action` such as `uses: actions/checkout@v6` will clone the repository at the URL composed by prepending the `DEFAULT_ACTIONS_URL` (`https://data.forgejo.org` by default)." `on.push` triggers "when a commit or a tag is pushed" with a `tags` filter; `on.release` (published, edited, deleted). Workflows in `.forgejo/workflows/`. Token available as `FORGEJO_TOKEN` and `GITHUB_TOKEN`; "the `github` context is defined to be the same as the `forgejo` context." Forgejo Runner v7.0.0+ for `FORGEJO_*` variables. [38]

**OIDC.** Forgejo only: "Forgejo Actions allows for workflows to request OpenID Connect compatible JWT ID tokens from Forgejo to exchange with external systems for credentials." Enabled with `enable-openid-connect` at workflow or job level (not `permissions: id-token`); the runner gets `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN`; claims include `ref`, `ref_type`, `ref_protected`, `repository`, `sha`, `workflow`, `workflow_ref`, `run_id`; issuer `[forgejo instance URL]/api/actions`; expiry `[actions].ID_TOKEN_EXPIRATION_TIME`, default 1 hour. [40][39] Gitea: `id-token` scope unsupported, so no OIDC.

**Signatures.** Gitea: "Gitea will verify gpg/ssh commit signatures in the provided tree by checking if the commits are signed by a key within the Gitea database, or if the commit matches the default key for Git." "Keys are not checked to determine if they have expired or revoked". Tags are not mentioned. [35] Forgejo docs are equally silent on tags, but Forgejo source has `ParseTagWithSignature` in `models/asymkey/gpg_key_tag_verification.go`, and the release list template includes `repo/tag/verification_line` and the tag list `repo/tag/verification_box`. [43][44]

**Packages.** Both: "Publish generic files, like release binaries or other output, for your user or organization." `PUT /api/packages/{owner}/generic/{package_name}/{package_version}/{file_name}`. [34][41]

**Provenance/attestation.** Nothing in either project's docs.

**Codeberg (runs Forgejo).** "Releases can be created using the Codeberg frontend or Codeberg's API — using Git to create new releases is not possible." "releases are tags accompanied with a binary file and are not part of Git". Releases must be enabled under Settings > Units. [45] CI: "Codeberg provides a Woodpecker CI instance at ci.codeberg.org." Access is by request form. "Forgejo Actions can be used with self-hosted runners and Codeberg also provides a hosted version in a limited fashion in open alpha." [46] Actions page cites "outstanding security issues" and "bus factor", and says "If you need Codeberg to host your CI, please use Woodpecker CI instead". [47] Woodpecker triggers: `when: - event: tag` with `ref: refs/tags/v*`. [48] Release uploads use the official `woodpeckerci/plugin-release`: "Woodpecker CI plugin to create a release and upload assets in the forge." "If the release already exists matching the tag, it will be used without overwriting. Files will still be uploaded based on the `file-exists` setting." (`file-exists` defaults to `overwrite`). "Supports Gitea, Forgejo and GitHub." [49]

## 3. sourcehut (man.sr.ht)

**No release object.** The unit is the annotated tag: "git.sr.ht allows you to attach files, such as executables (aka binaries), PGP signatures, and so on, to *annotated tags*." The tag message is the release note: "you'll be prompted to *annotate* the tag — fill this in with release notes, a changelog, etc." Upload: "To attach files to it, click the tag name (e.g. "2.3.4") and use the upload form on this page." Push with `git push --tags` or `git push --follow-tags` (`push.followTags true`). [50]

**API.** GraphQL schema: `uploadArtifact(repoId: Int!, revspec: String!, file: Upload!): Artifact!`, documented as "Uploads an artifact. revspec must match a specific git tag, and the filename must be unique among artifacts for this repository." `Artifact` carries `id`, `created`, `filename`, `checksum`, `size`, `url`; `deleteArtifact(id)`. [53] `hut git artifact upload <filename...> --rev <string>` where `--rev` is "Revision tag. Defaults to the last Git tag."; also `artifact list`, `artifact delete <ID>`. [54]

**Tarball signatures.** "git.sr.ht may also serve PGP signatures for those tarballs with `.asc` appended." Signatures are notes under `refs/notes/signatures/tar{,.gz}`, generated with `git archive` and `gpg --detach-sign`; "you must compress with `gzip -n`!" [50]

**Build triggers on tags.** "git.sr.ht will automatically submit builds for you if you store a manifest in the repository as `.build.yml`." With a `submitter: git.sr.ht:` block, "If `allow-refs` is present, the build is submitted if and only if the reference matches one of the `allow-refs` values." Example uses `"refs/tags/*"`. Builds receive `GIT_REF`. `git push -o skip-ci` suppresses. [50] Manifest `triggers`: "A list of triggers to execute post-build, which can be used to send emails or do other post-build tasks." (email/webhook; condition `always`, `success`, `failure`). Manifest `artifacts`: files "made available for downloading from the jobs page", 1 GiB each, pruned after 90 days. [51][52]

## 4. Bitbucket Cloud

**No release object.** Only "Downloads": `POST /repositories/{workspace}/{repo_slug}/downloads`: "Upload new download artifacts. To upload files, perform a `multipart/form-data` POST containing one or more `files` fields". Crucially: "When a file is uploaded with the same name as an existing artifact, then the existing file will be replaced." Plus `GET` list, `GET`/`DELETE` by filename. [56] Pipelines docs show `curl -X POST .../downloads --form files=@$FILENAME` and the `atlassian/bitbucket-upload-file` pipe. [57]

**Tags.** "While Git supports annotated and lightweight tags, you can only create and see annotated tags in Bitbucket." Signed tags: `-S` and `git tag -v`; deletion only from the command line. [55]

**Tag restrictions.** Branch restrictions have `kind` in `push`, `delete`, `force`, `restrict_merges`, and merge checks; `pattern` is documented as "Apply the restriction to branches that match this pattern." No tag kind exists in the API and the branch-permissions page never mentions tags. [56][58] Immutable tags exist only for the container registry. [59]

**Pipelines.** `tags:` "Defines all tag-specific build pipelines. The names or expressions in this section are matched against tags and annotated tags in your Git repository." Glob patterns. [60] `BITBUCKET_TAG`: "Tag name (tags only)". [61] OIDC: `oidc: true` on a step yields `BITBUCKET_STEP_OIDC_TOKEN`; up to 10 custom audiences. [62]

## 5. Radicle (radicle.xyz now 307-redirects to radicle.dev)

**No release object, no assets.** Each peer keeps its own namespace: `refs/namespaces/<nid>/refs/heads`, `refs/namespaces/<nid>/refs/tags`. "Radicle automatically signs the entirety of a node's references every time they change." The signature lives "in a Git blob under a special branch referenced under `refs/rad/sigrefs`." Canonical state comes from the "signature **threshold** defined in the repository's identity document". [63]

**Tags as canonical refs.** Since 1.3.0, `xyz.radicle.crefs` rules extend canonicality to tags; the announcement's example rule is `refs/tags/releases/*` with three allowed DIDs and threshold 2. [64] The `rad id` man page shows `rad id update --payload xyz.radicle.crefs rules '{ ... "refs/tags/*": { "threshold": 2, "allow": "delegates" } ... }'`. [65] 1.9.0 (2026-05-19) adds symbolic canonical refs. [66] 1.8.0 (2026-03-30) introduced sigrefs feature levels (`none`, `root`, `parent`) after a replay-attack disclosure. [67] So a Radicle "release" is a tag that enough delegates have signed.

## 6. Plain Git (git-scm.com; pages report 2.50 to 2.55)

- Annotated vs signed: "-a --annotate Make an unsigned, annotated tag object"; "-s --sign Make a cryptographically signed tag, using the default signing key. The signing backend used depends on the `gpg.format` configuration variable." "Annotated tags are meant for release while lightweight tags are meant for private or temporary object labels." Re-tagging: "Git does **not** (and it should not) change tags behind users back." `--contains` lists tags containing a commit. `--sort=version:refname` (alias `v:refname`) is affected by `versionsort.suffix`. [68]
- Verification: `git verify-tag` "Validates the GPG signature created by `git tag`". [69] `gpg.format` is `openpgp`, `x509` or `ssh`; `gpg.ssh.allowedSignersFile` is "A file containing ssh public keys which you are willing to trust." `tag.gpgSign`, `tag.forceSignAnnotated`, `tag.sort` exist. [75][76]
- Archives: `export-ignore` files "won't be added to archive files"; `export-subst` expands `$Format:PLACEHOLDERS$` only when a commit or tag is given, and only one `%(describe)` per archive. [70] `git archive` stores the commit ID "in a global extended pax header" (tar) or as a file comment (zip); `--prefix`, `--format` (tar, zip, tar.gz, tgz, `tar.<format>.command`), `--mtime`; committer time is used as mtime. [71]
- Version discovery: `git describe` "finds the most recent tag that is reachable from a commit", annotated tags only unless `--tags`; output like `v1.0.4-14-g2414721`; `--match`, `--exclude`, `--dirty`, `--always`, `--first-parent`. [72] `git for-each-ref --sort=version:refname`, `--points-at`, `--contains`, fields `taggerdate`, `contents:subject`, `contents:body`, `%(if)`. [73]
- Prerelease ordering: `versionsort.suffix` (verbatim): "By specifying a single suffix in this variable, any tagname containing that suffix will appear before the corresponding main release." The empty suffix positions the final release among suffixes; `versionsort.prereleaseSuffix` is a deprecated alias. [74]
- Pushing: `--follow-tags` pushes "annotated tags in `refs/tags` that are missing from the remote but are pointing at commit-ish that are reachable from the refs being pushed"; `--tags`; `--atomic`; `--signed`; `push.followTags`. [77][78]
- SHA-256: `git init --object-format`: "The valid values are sha1 and (if enabled) sha256. sha1 is the default. Note: At present, there is no interoperability between SHA-256 repositories and SHA-1 repositories." "Today, we only expect compatible changes." [79] `extensions.compatObjectFormat` is "incomplete and subject to change ... not designed to be enabled by end users." [80]

## 7. Comparison table

| Host | Release object | Assets | Immutability | Protected tags | Tag signature verification | OIDC / keyless | Provenance / attestation | CI trigger on tag |
|---|---|---|---|---|---|---|---|---|
| GitLab | Yes, bound to tag; evidence JSON | Auto source archives + links; binaries via generic packages | No; API PUT/DELETE; `release:` refuses to update existing | Yes, wildcards, roles/users/deploy keys, "No one" | Yes, SSH/GPG/X.509 "Verified" (tags GA 19.1) | Yes, `id_tokens` with `aud: sigstore` | Yes, SLSA 1.0 provenance; L3 attestations Experiment (Ultimate, GitLab.com) | `rules: - if: $CI_COMMIT_TAG` |
| Gitea | Yes, drafts/prereleases | Uploaded attachments + generic packages | No; editable via API | Yes, glob or regex, users/teams | Commits documented; tags not documented | No (`id-token` scope unsupported) | None documented | `on: push: tags:`; `release` event |
| Forgejo / Codeberg | Yes | Attachments, external links, source archives | No | Yes, glob or regex | Tags verified in code; docs silent | Yes, `enable-openid-connect` (Fulcio trust unverified) | None documented | `on: push: tags:`; Woodpecker `event: tag` |
| sourcehut | No; annotated tag is the release | Files attached to tags; tarball `.asc` via notes | No delete protection documented | No | Not documented | No | No | `.build.yml` `allow-refs: refs/tags/*`, `GIT_REF` |
| Bitbucket Cloud | No; Downloads only | Downloads, overwritten on same name | No | No tag kind in API | Not shown; verify locally | Yes, `oidc: true` | No | `pipelines: tags:`, `BITBUCKET_TAG` |
| Radicle | No | None | Tags canonical only with delegate threshold | Yes, via `xyz.radicle.crefs` rules | Signed refs (Ed25519 node keys) | No | No | No hosted CI documented |

## 8. Conclusion: the host-independent release and the adapters

**The portable core is an annotated, signed tag plus artifacts derived from it.** Every host consumes an annotated tag: sourcehut and Radicle have nothing else, Bitbucket only shows annotated tags, and GitLab, Gitea and Forgejo generate their source archives from the tag. The host-independent release therefore consists of:

1. An annotated tag (`git tag -a` or `-s`) whose message is the release note, pushed with `git push --follow-tags` or `--atomic`.
2. A source archive from `git archive --prefix=<name>-<ver>/ <tag>` with `export-ignore`/`export-subst` attributes and `gzip -n` for reproducibility (sourcehut requires exactly this).
3. Version discovery via `git describe`, `git tag --sort=version:refname` with `versionsort.suffix` for prereleases, and `git tag --contains`.
4. Detached signatures and provenance shipped as files (GPG `.asc`, cosign bundles, in-toto JSON), because only GitLab stores attestations server-side.
5. Verification with `git verify-tag` and `gpg.ssh.allowedSignersFile`, which works offline on every host.

**What must be adapted per host:** creating the release object (GitLab `release:`/glab/REST; Gitea and Forgejo `POST .../releases` then `POST .../releases/{id}/assets`; sourcehut `uploadArtifact` on the tag; Bitbucket `POST .../downloads`; Radicle nothing), the asset model (links plus package registry on GitLab, uploads elsewhere, none on Radicle), tag protection configuration, the CI tag trigger syntax, and the OIDC hook if keyless signing is wanted (GitLab and Forgejo issue tokens; Gitea, sourcehut, Radicle do not). No host offers an immutable release object, so immutability has to come from protected tags plus refusing to overwrite existing releases and assets (Bitbucket Downloads and the Woodpecker plugin default to overwrite).

## Could not verify

- Gitea: whether signed tags render a Verified badge (docs silent; source path guess returned 404).
- Gitea and Forgejo: whether `.github/workflows` is honored in addition to `.gitea/` or `.forgejo/workflows`.
- Forgejo: whether public Sigstore Fulcio trusts Forgejo OIDC issuers, so keyless signing remains unverified.
- sourcehut: tag-object signature display on the tag page, artifact size limits, and whether a legacy REST artifact endpoint still exists.
- Bitbucket Cloud: any git-tag protection at all (docs silent, API has no tag kind); full claim list of the OIDC token; the "only annotated tags" statement was quoted, not tested.
- Radicle: any binary attachment mechanism, and Radicle CI options.
- GitLab: whether SLSA level 3 attestations have left Experiment status after 18.3 (page still says Experiment); X.509 tag badge history (only the SSH page carries a tag-specific history block); exact `release-cli` image and flags, since the page now only documents the migration.
- Codeberg docs contain no release-upload CI example; the plugin evidence comes from Woodpecker's own plugin repo.

## Sources (all accessed 2026-09-24)

1. https://docs.gitlab.com/user/project/releases/
2. https://docs.gitlab.com/user/project/releases/release_fields/
3. https://gitlab.com/gitlab-org/gitlab/-/raw/master/doc/ci/yaml/_index.md (source of https://docs.gitlab.com/ci/yaml/)
4. https://docs.gitlab.com/user/project/releases/release_cli/
5. https://docs.gitlab.com/cli/release/create/
6. https://docs.gitlab.com/cli/release/upload/
7. https://docs.gitlab.com/api/releases/
8. https://docs.gitlab.com/api/releases/links/
9. https://docs.gitlab.com/user/packages/generic_packages/
10. https://docs.gitlab.com/user/project/protected_tags/
11. https://docs.gitlab.com/user/project/repository/tags/
12. https://docs.gitlab.com/user/project/repository/signed_commits/
13. https://gitlab.com/gitlab-org/gitlab/-/raw/master/doc/user/project/repository/signed_commits/ssh.md (source of https://docs.gitlab.com/user/project/repository/signed_commits/ssh/)
14. https://docs.gitlab.com/ci/secrets/id_token_authentication/
15. https://docs.gitlab.com/ci/yaml/signing_examples/
16. https://docs.gitlab.com/ci/runners/configure_runners/
17. https://gitlab.com/gitlab-org/gitlab/-/raw/master/doc/ci/pipeline_security/slsa/_index.md
18. https://gitlab.com/gitlab-org/gitlab/-/raw/master/doc/ci/pipeline_security/slsa/level_3/_index.md
19. https://docs.gitlab.com/api/attestations/
20. https://docs.gitlab.com/user/project/releases/release_evidence/
21. https://docs.gitlab.com/ci/variables/predefined_variables/
22. https://docs.gitlab.com/ci/jobs/job_rules/
23. https://docs.gitlab.com/user/packages/container_registry/immutable_container_tags/
24. https://docs.gitea.com/api/next/operations/repo-create-release/
25. https://docs.gitea.com/api/next/operations/repo-create-release-attachment/
26. https://docs.gitea.com/api/next/operations/repo-create-tag/
27. https://docs.gitea.com/api/next/operations/repo-create-tag-protection/
28. https://docs.gitea.com/usage/protected-tags
29. https://docs.gitea.com/usage/actions/overview
30. https://gitea.com/gitea/docs/raw/branch/main/docs/usage/actions/comparison.md (source of https://docs.gitea.com/usage/actions/comparison)
31. https://gitea.com/gitea/docs/raw/branch/main/docs/usage/actions/faq.md
32. https://docs.gitea.com/usage/actions/quickstart
33. https://docs.gitea.com/usage/actions/act-runner
34. https://docs.gitea.com/usage/packages/generic
35. https://docs.gitea.com/administration/signing
36. https://forgejo.org/docs/latest/user/repository/releases/
37. https://forgejo.org/docs/latest/user/protection/
38. https://forgejo.org/docs/latest/user/actions/reference/
39. https://forgejo.org/docs/latest/user/actions/github-actions/
40. https://forgejo.org/docs/latest/user/actions/security-openid-connect/
41. https://forgejo.org/docs/latest/user/packages/generic/
42. https://forgejo.org/docs/latest/user/api-usage/
43. https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/models/asymkey/gpg_key_tag_verification.go
44. https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/templates/repo/release/list.tmpl and https://codeberg.org/forgejo/forgejo/raw/branch/forgejo/templates/repo/tag/list.tmpl
45. https://docs.codeberg.org/git/using-tags/
46. https://docs.codeberg.org/ci/
47. https://docs.codeberg.org/ci/actions/
48. https://woodpecker-ci.org/docs/usage/workflow-syntax
49. https://codeberg.org/woodpecker-plugins/release/raw/branch/main/docs.md
50. https://git.sr.ht/~sircmpwn/sr.ht-docs/blob/master/git.sr.ht/index.md (source of https://man.sr.ht/git.sr.ht/)
51. https://man.sr.ht/builds.sr.ht/manifest.md
52. https://man.sr.ht/builds.sr.ht/triggers.md
53. https://git.sr.ht/~sircmpwn/git.sr.ht/blob/master/api/graph/schema.graphqls
54. https://git.sr.ht/~xenrox/hut/blob/master/doc/hut.1.scd
55. https://support.atlassian.com/bitbucket-cloud/docs/repository-tags/
56. https://api.bitbucket.org/swagger.json (Bitbucket Cloud REST API 2.0 OpenAPI; downloads and branch-restrictions groups)
57. https://support.atlassian.com/bitbucket-cloud/docs/deploy-build-artifacts-to-bitbucket-downloads/
58. https://support.atlassian.com/bitbucket-cloud/docs/use-branch-permissions/
59. https://support.atlassian.com/bitbucket-cloud/docs/set-up-and-use-immutable-tags-in-the-container-registry/
60. https://support.atlassian.com/bitbucket-cloud/docs/pipeline-start-conditions/
61. https://support.atlassian.com/bitbucket-cloud/docs/variables-and-secrets/
62. https://support.atlassian.com/bitbucket-cloud/docs/integrate-pipelines-with-resource-servers-using-oidc/
63. https://radicle.dev/guides/protocol (redirect target of https://radicle.xyz/guides/protocol)
64. https://radicle.dev/2025/08/12/canonical-references
65. https://raw.githubusercontent.com/radicle-dev/heartwood/master/rad-id.1.adoc
66. https://radicle.dev/2026/05/19/radicle-1.9.0
67. https://radicle.dev/2026/03/30/radicle-1.8.0
68. https://git-scm.com/docs/git-tag
69. https://git-scm.com/docs/git-verify-tag
70. https://git-scm.com/docs/gitattributes
71. https://git-scm.com/docs/git-archive
72. https://git-scm.com/docs/git-describe
73. https://git-scm.com/docs/git-for-each-ref
74. https://raw.githubusercontent.com/git/git/master/Documentation/config/versionsort.adoc
75. https://raw.githubusercontent.com/git/git/master/Documentation/config/gpg.adoc
76. https://raw.githubusercontent.com/git/git/master/Documentation/config/tag.adoc
77. https://raw.githubusercontent.com/git/git/master/Documentation/config/push.adoc
78. https://git-scm.com/docs/git-push
79. https://git-scm.com/docs/git-init
80. https://raw.githubusercontent.com/git/git/master/Documentation/config/extensions.adoc
