# 0008. Other git hosts: what carries over and what is an adapter

Status: accepted (2026-09-24). Research: [`docs/research/r7-hosts.md`](../research/r7-hosts.md)
(GitLab, Gitea, Forgejo/Codeberg, sourcehut, Bitbucket Cloud, Radicle and plain git, from their own documentation on 2026-09-24).

## The host-independent core

Every host consumes an annotated git tag: sourcehut and Radicle have no
other release concept ("git.sr.ht allows you to attach files … to
*annotated tags*"; a Radicle release is a tag signed by enough delegates),
Bitbucket only shows annotated tags, and GitLab, Gitea and Forgejo derive
source archives from them. Everything in this repository up to and
including the build is therefore portable:

- the signed annotated tag as the release event and its message as the
  release notes ([0003](0003-signed-tag-trigger.md));
- `CHANGELOG.md` as the version source ([0002](0002-changelog-as-version-source.md));
- `scripts/verify-tag.sh` with `gpg.ssh.allowedSignersFile`, which
  verifies offline on any clone;
- the Nix build, the deterministic archives, `SHA256SUMS` and the
  stock-Go reproduction ([0004](0004-reproducible-build.md));
- `scripts/release.sh`, whose only GitHub-specific part is the optional
  pull-request call.

## What differs per host

| Host | Release object | Assets | Immutability | Tag protection | Tag signature shown | OIDC for keyless signing | Provenance |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GitHub | Yes, immutable option | Uploads (2 GiB each, 1000 per release), server digests | Tag and assets frozen at publish | Rulesets | GPG/SSH/S/MIME "Verified" | Yes | Attestations API, SLSA L2 |
| GitLab | Yes, bound to a tag, plus "release evidence" JSON | Links; binaries in the generic package registry | No; `release:` refuses to update an existing release | Protected tags, push rules | SSH tag verification GA in 19.1 | `id_tokens` with `aud: sigstore` | SLSA 1.0 provenance from the runner; L3 attestations are an Ultimate-tier experiment |
| Gitea | Yes (draft, pre-release) | Attachments, generic packages | No | Glob or regex, users/teams | Commits documented, tags not | No (`id-token` unsupported) | None |
| Forgejo / Codeberg | Yes | Attachments, links | No | Glob or regex | Verified in code, undocumented | `enable-openid-connect` | None |
| sourcehut | No; the tag is the release | Files attached to tags; tarball `.asc` via notes | None documented | No | Not documented | No | None |
| Bitbucket Cloud | No; "Downloads" | Overwritten on same name | No | No tag kind in the API | Not shown | `oidc: true` | None |
| Radicle | No | None | Canonical tags need a delegate threshold | `xyz.radicle.crefs` rules | Signed refs | No | None |

Two consequences shape the adapter design:

1. **No other host has an immutable release object.** Immutability must
   come from protected tags plus a publish script that refuses to touch an
   existing release or asset; Bitbucket Downloads and the Woodpecker
   release plugin overwrite by default, so the script must check first.
2. **Only GitLab and Forgejo issue OIDC tokens from CI**, so keyless
   Sigstore attestations are possible there (GitLab's `SIGSTORE_ID_TOKEN`;
   Forgejo's issuer is instance-specific and its trust by the public
   Fulcio is unverified). Elsewhere, provenance and SBOM must be shipped
   as files signed with a project key, which is what SLSA calls L1 with
   authenticity supplied out of band.

## Decision

`scripts/github-release.sh` is the GitHub adapter and the template for the
others; an adapter is one script that (a) checks that no release or asset
already exists for the tag, (b) creates the release object if the host
has one, (c) uploads or links the assets from `result/`, (d) publishes
last. Sketches from the researched documentation:

- **GitLab**: `POST /projects/:id/releases` with `tag_name` after uploading
  binaries to `PUT /projects/:id/packages/generic/relver/<version>/<file>`
  and adding them as `assets.links`; trigger with `rules: - if:
  $CI_COMMIT_TAG`; sign with cosign using an `id_tokens:` entry with
  `aud: sigstore` and record the bundle as an asset. Note that
  `release-cli` is deprecated (GitLab 18.0, removal in 20.0) in favour of
  `glab`, so the adapter should call the REST API directly as here.
- **Gitea / Forgejo**: `POST /repos/{owner}/{repo}/releases` with
  `draft: true`, then `POST …/releases/{id}/assets`, then `PATCH` to
  publish; protect `v*` tags with the tag-protection API; run the same
  workflow files under `.gitea/` or `.forgejo/workflows/` with
  `actions/checkout` resolved from the configured actions source
  (Forgejo "is *not* designed to be compatible" and ignores
  `permissions`, so the least-privilege model must be re-expressed with
  the host's token scopes).
- **sourcehut**: nothing to create; `hut git artifact upload <files>
  --rev vX.Y.Z` attaches the archives to the tag, and the tag message is
  the release note. builds.sr.ht triggers on `refs/tags/*` via
  `allow-refs`.
- **Bitbucket Cloud**: `POST /repositories/{ws}/{slug}/downloads` after
  listing existing downloads to refuse an overwrite; pipelines
  `tags:` trigger.
- **Radicle**: no artifacts; the release is the canonical tag under a
  `refs/tags/*` rule with a delegate threshold.

The host-specific surface stays one script per host; the trust anchor
(the maintainer's signed tag) and the reproducibility evidence do not
move.

## Sources

GitLab: releases, release fields, CI YAML `release:` keyword, release-cli
deprecation, releases API, generic packages, protected tags, signed
commits/tags, ID tokens, signing examples, runner artifact metadata, SLSA
overview and level 3, attestations API. Gitea: release and tag-protection
API, protected tags, Actions comparison and FAQ, signing. Forgejo:
releases, protection, Actions reference and OpenID Connect, generic
packages. Codeberg: tags, CI, Actions. sourcehut: git.sr.ht docs, GraphQL
schema, hut manual, builds.sr.ht manifest and triggers. Bitbucket:
repository tags, REST OpenAPI (downloads, branch restrictions), pipeline
start conditions, OIDC. Radicle: protocol guide, canonical references,
1.8.0 and 1.9.0 notes. Git: git-tag, git-verify-tag, gitattributes,
git-archive, git-describe, git-for-each-ref, git-push, config
(versionsort, gpg, tag, push, extensions). All accessed 2026-09-24; URLs
in the research digest.
