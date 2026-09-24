<!-- Research digest produced for this repository on 2026-09-24 from primary sources only (specifications, official documentation, changelogs, official repositories). Quotes are verbatim; every source URL and its access date are listed at the end. Items the research could not verify are listed explicitly. -->

# Nix flakes and Nix in GitHub Actions for a small Go CLI — research report

Status: COMPLETE. Every claim was verified against a live primary source on 2026-09-24. Source keys `[S#]` map to the numbered list at the end. Quotes are verbatim and kept under 40 words.

## 1. Nix versions

**Latest upstream Nix: 2.35.2. Master is 2.36.0-dev.** Newest tag in NixOS/nix is `2.35.2` (no 2.36 tag); the nix.dev "latest" manual header says "Nix 2.35.2"; nixos.org/download shows 2.35.2; the 2.35.2 tarball has `Last-Modified: Wed, 12 Aug 2026`. Master `.version` is `2.36.0` (commit 8f7ed1c, 2026-09-23) and `doc/manual/rl-next` holds no flake-related notes (only auto-call-function-installables, infinite-recursion-start, optimise-alias, s3-endpoint-url, warn-indentation). [S1, S2, S3, S4]

- Release-notes heading: "Release 2.35 (2026-06-22)". Discourse announcement (Lisanna, 2026-07-13): "On behalf of the Nix team, I am pleased to finally announce the release of Nix 2.35.0." It "also fixes a security issue with recursive-nix" (GHSA-6h4g-g5j9-fm5f). 2.35.1 tarball: 2026-07-14. [S2 rl-2.35, S5]
- 2.35 flake-relevant notes (verbatim): "Sources are copied to the store more lazily"; "builtins.getFlake now supports path values"; "Support SCP-like URLs in fetchGit and type = 'git' flake inputs"; "The revCount attribute of Git fetchers is now lazily computed"; "GitHub fetcher now validates URL parameters" (a `tag` parameter is now rejected); HTTP/3 (`http3` setting); mimalloc "5–12% wall-clock improvement". [S2 rl-2.35]
- 2.34 ("2026-02-27"): "Experimental feature `no-url-literals` has been stabilised and is now controlled by the `lint-url-literals` option"; "Content-addressed cache for `builtins.fetchTarball` and tarball-based flake inputs now writes git blobs concurrently"; "Relative `file:` paths for tarballs are now rejected with a clear error". [S2 rl-2.34]
- Cadence: "Nix has a release cycle of roughly 6 weeks" (release-notes index); RFC 106: "Do a new Nix release every 6 weeks." [S2 index, S6]

**Flakes are still experimental in 2.35.2.** The experimental-features page lists `flakes` ("Enable flakes. See the manual entry for `nix flake` for details."), `nix-command`, and `fetch-tree` ("The `flakes` feature flag always enables `fetch-tree`."). No stabilization statement exists in the manual. RFC 0136 "A plan to stabilize the new CLI and Flakes incrementally" was merged 2023-08-13. Nix team post (fricklerhandwerk, 2023-11-16): plan to "break down the `flakes` experimental feature into components that can be stabilised one by one", starting with `builtins.fetchTree`; "we can't commit to a timeline". No later official milestone found. Steering Committee (fpletz, 2025-03-09): "if the evolving flake interface were to diverge between Nix and Determinate Nix, Nixpkgs and other official projects would continue to support Nix's definition." [S2 experimental-features, S7, S8, S9]

**Lix:** newest tag `2.95.3` (created 2026-05-08); blog "Announcing Lix 2.95 'Kakigōri'" 2026-03-25; 2.94 on 2025-11-18. [S10]

**Determinate Nix:** v3.22.5, "Release 3.22.5 (2026-09-17)", "Based on upstream Nix 2.35.2"; README: "It's based on the upstream Nix CLI and continuously rebased against it". [S11]

**Default Nix per installer action:**

| Action (pinned) | Default Nix |
|---|---|
| cachix/install-nix-action v31.11.1 | `nix_version=2.35.2`; installer URL `https://releases.nixos.org/nix/nix-2.35.2/install` |
| nixbuild/nix-quick-install-action v35 | action.yml `nix_version` `default: "2.34.7"` |
| DeterminateSystems/nix-installer-action v23 | `determinate` input `default: true`; README: "This Action installs Determinate Nix by default." |
| DeterminateSystems/determinate-nix-action v3.22.5 | nix-installer v3.22.5 = Determinate Nix 3.22.5 (upstream 2.35.2) |

[S12, S13, S14, S15]

## 2. Nixpkgs branches, schedule, Go

**Current stable: NixOS 26.05 "Yarara" (2026-05-30). Rolling: `nixos-unstable`.** git ls-remote on nixpkgs lists `release-26.05`, `nixos-26.05`, `nixos-26.05-small`, `nixpkgs-26.05-darwin`, `nixos-unstable`, `nixos-unstable-small`, `nixpkgs-unstable`; no `*26.11*` branch exists yet. Release-notes heading: `# Release 26.05 ("Yarara", 2026.05/30)`; previous: 25.11 "Xantusia" 2025-11-30. The 26.05 notes contain no Go or Nix-version bullet. [S16, S17]

- Schedule (RFC 80): "all subsequent releases will occur six months apart following a YY.05 and YY.11 convention." nix.dev FAQ: "A new stable release is made every six months". [S18, S19]
- Which branch (nix.dev FAQ): Linux stable → `nixos-*` (pre-built, passed the NixOS test suite); Linux rolling → `nixos-unstable`; macOS stable → `nixpkgs-*-darwin`; macOS rolling → `nixpkgs-unstable`. nixpkgs CONTRIBUTING: "`master`: The main branch, used for the unstable channels `nixos-unstable`, `nixos-unstable-small` and `nixpkgs-unstable`." [S19, S20]
- Input URL forms. Manual: "`github:NixOS/nixpkgs/nixos-20.09`: The `nixos-20.09` branch of the `nixpkgs` repository." The official NixOS/templates now use channel tarballs instead: go-hello has `inputs.nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.zst";`, trivial has `nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";`. Those lock through the "Lockable HTTP Tarball Protocol" (`Link: <flakeref>; rel="immutable"`). [S2 nix3-flake, S21, S2 tarball-fetcher]

**Go versions (all-packages.nix + `pkgs/development/compilers/go/*.nix`):**

| Branch | `go` / `buildGoModule` | `go_latest` | Also present |
|---|---|---|---|
| nixos-unstable | `go = go_1_26;` = 1.26.7; `buildGoModule = buildGo126Module;` | `go_latest = go_1_27;` = 1.27.1 | – |
| nixos-26.05 | `go = go_1_26;` = 1.26.7 | `go_latest = go_1_26;` | go_1_25 = 1.25.13, go_1_27 = 1.27.1 |
| nixos-25.11 | `go = go_1_25;` = 1.25.10 | – | go_1_24, go_1_26 = 1.26.4 |

Policy (pkgs/build-support/go/README.md): "Default toolchain (the `go` package) and builder (`buildGoModule`) are upgraded to the latest minor release of Go as soon as it is released"; "Consumers outside of nixpkgs on the other hand MAY rely on this toolchain/builder [go_latest/buildGoLatestModule]". [S22, S23]

## 3. Flake schema and best practice

**Top-level attributes (manual):** `description`, `inputs`, `outputs`, `nixConfig`. Input/`self` metadata listed verbatim: `outPath`, `rev` ("if applicable"), `revCount` ("not available for `github` repositories"), `lastModifiedDate` ("format `%Y%m%d%H%M%S`"), `lastModified`, `narHash`. "The value returned by the `outputs` function must be an attribute set." [S2 nix3-flake]

**Attributes actually emitted** (`builtins.fetchTree` doc + `emitTreeAttrs` in `src/libexpr/primops/fetchTree.cc`): `outPath`, `narHash`, `submodules` (git only), `rev`, `shortRev`, `revCount`, `dirtyRev`, `dirtyShortRev`, `lastModified`, `lastModifiedDate`, plus "backend-specific metadata (currently not documented)". Code comment: "// FIXME: support arbitrary input attributes." `dirtyRev` = `<headRev>-dirty` (git.cc). `self.sourceInfo` exists: flake.cc allocates a `sourceInfo` binding and fills it via `emitTreeAttrs(...)`. [S2 builtins, S24, S25, S26]

**Git tags: confirmed unobservable.** No `ref`/`tag` attribute is documented or emitted; only `rev`/`shortRev`/`revCount`/`lastModified*`/`dirty*`. The root lock node carries no locked data: "we cannot record the commit hash or content hash of the root flake, since modifying `flake.lock` will invalidate these." The official go-hello template therefore uses `version = builtins.substring 0 8 lastModifiedDate;`. (Inferred from the attribute list and code; the manual has no literal "tags are unavailable" sentence.) [S2 nix3-flake, S24, S21]

**Standard outputs** (from `nix flake check` rules): derivations at `checks.<system>.<name>`, `devShells.<system>.{default,<name>}`, `packages.<system>.{default,<name>}`, `nixosConfigurations.<name>.config.system.build.toplevel`; app definitions at `apps.<system>.*`; `templates.*`; `overlays.{default,<name>}`; `nixosModules.*`; `bundlers.*`; `hydraJobs` and `legacyPackages.<system>` are evaluated specially. Legacy names (`defaultPackage.<system>`, `devShell.<system>`, `overlay`…) "will work but will emit a warning". `formatter.<system>` is consumed by `nix fmt` (nixfmt README). [S2 nix3-flake-check, S27]

**`nix flake check`:** "verifies that the flake … can be evaluated successfully … and that the derivations specified by the flake's `checks` output can be built successfully." `--no-build`: "Do not build checks." `--all-systems`: "Check the outputs for all systems." Default is the current system only: flake.cc skips `system != localSystem` and warns "The check omitted these incompatible systems: %s / Use '--all-systems' to check all." `keep-going` continues past errors. [S2 nix3-flake-check, S28]

**`nix flake lock` vs `update`:** lock "contains an up-to-date lock for every flake input specified in `flake.nix`. Lock file entries are already up-to-date are not modified." update: "By default, all inputs are updated"; `nix flake update nixpkgs` updates one; `--commit-lock-file`; `--override-input … implies --no-write-lock-file`. Lock file is JSON `"version": 7`. [S2 nix3-flake-lock, nix3-flake-update, nix3-flake]

**`nixConfig`:** "a set of `nix.conf` options to be set when evaluating any part of a flake." Without `accept-flake-config` (default false) only `bash-prompt`, `bash-prompt-prefix`, `bash-prompt-suffix`, `flake-registry`, `commit-lock-file-summary` apply unprompted. Self-attributes `inputs.self.submodules` / `inputs.self.lfs` exist. [S2 nix3-flake, conf-file]

**Per-system iteration without flake-utils (official templates):** go-hello: `forAllSystems = nixpkgs.lib.genAttrs supportedSystems;` over `x86_64-linux x86_64-darwin aarch64-linux aarch64-darwin`, then `packages = forAllSystems (system: … pkgs.buildGoModule { … vendorHash = null; })`; trivial: `builtins.mapAttrs (system: pkgs: …) inputs.nixpkgs.legacyPackages`. nixpkgs' own list is `lib.systems.flakeExposed` (lib/systems/flake-systems.nix). [S21, S29]

**flake-utils / flake-parts:** nix.dev neither discourages nor endorses: "Flakes have no parameters. … This is made easier by say `flake-utils`." and flake-parts "lets you spread code over different flake-like files." nix.dev's stance: "Flakes are an experimental extension format with outstanding issues." and "Files must be staged for flakes to see them." [S30]

**Formatter:** "Nixfmt is the official formatter for Nix language code" (donated "with the acceptance of RFC 166"). nixpkgs attribute is `nixfmt` (1.5.0; GitHub release 1.5.0 dated 2026-09-10). `nixfmt-rfc-style` is an alias since 2025-07-14 warning "nixfmt-rfc-style is now the same as pkgs.nixfmt which should be used instead."; `nixfmt-classic` throws since 2026-07-01. `nixfmt-tree`: "Official Nix formatter zero-setup starter using treefmt"; README recommends `formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;`. nixpkgs CONTRIBUTING: "CI enforces all Nix files to be formatted using the official Nix formatter" via `nix fmt`/`treefmt`. nix.dev has no formatter recommendation. [S27, S31, S32, S20]

## 4. `buildGoModule` (manual go.section.md + module.nix)

- `vendorHash`: "Hash of the output of the intermediate fetcher derivation". "`vendorHash` can be set to `null`. In that case, rather than fetching the dependencies, the dependencies already vendored in the `vendor` directory of the source repo will be used." module.nix: "If `null`, it means the project either has no external dependencies or the vendored dependencies are already present in the source tree." Obtain with `vendorHash = lib.fakeHash;`.
- `ldflags`: "A string list of flags to pass to the Go linker tool via the `-ldflags` argument of `go build`." (e.g. `-X main.Version=${version}`). `-buildid=` is appended by default: "If not set to an explicit value, set the buildid empty for reproducibility."
- `tags` (`-tags`), `subPackages` ("Limits the builder from building child packages that have not been listed"), `excludedPackages`, `modRoot`, `proxyVendor` ("Defaults to `false`"; uses `go mod download` module cache), `deleteVendor`, `goSum`, `allowGoReference`, `buildTestBinaries`, `GOFLAGS`, `enableParallelBuilding`.
- `env.CGO_ENABLED`: "When set to `0`, the cgo command is disabled … the resulting binary is statically linked." "`env.CGO_ENABLED` defaults to `1`." (module.nix: `CGO_ENABLED = args.env.CGO_ENABLED or go.CGO_ENABLED;`; toolchain default 1 except wasi/ppc64be.)
- `-trimpath` is on by default: "`-trimpath` is added by default to GOFLAGS by buildGoModule when allowGoReference isn't set to true". Also `GOFLAGS=-mod=vendor` (unless `proxyVendor`), `GOPROXY=off`, `GOSUMDB=off`, `GOTOOLCHAIN=local`, `GO111MODULE=on`. Tests run with `-trimpath` stripped ("in case they reference test assets").
- **GOOS/GOARCH cannot be overridden per package.** module.nix sets `env = args.env or { } // { inherit (go) GOOS GOARCH; … }`, so `env.GOOS` is overwritten by the toolchain's values, which come from `inherit (stdenv.targetPlatform.go) GOOS GOARCH GOARM;` (go/1.26.nix). A top-level `GOOS = …` attribute trips stdenv's check: "The `env` attribute set cannot contain any attributes passed to derivation. The following attributes are overlapping:". Cross-compile via `pkgsCross.<name>.buildGoModule`; module.nix then normalizes ("# normalize cross-compiled builds w.r.t. native builds", moving `$GOPATH/bin/${GOOS}_${GOARCH}/*` up).
- **Tests under cross:** buildGoModule sets `doCheck = args.doCheck or (!buildTestBinaries);`, but stdenv applies `doCheck' = doCheck && canExecuteHostOnBuild;`, so tests are skipped automatically when the builder can't execute host binaries. Manual idiom: `{ doCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform; }`.
- Skipping tests: `checkFlags = [ "-run=^Test(Simple|Fast)$" ]` / `-skip=…`; "To disable tests altogether, set `doCheck = false;`."
- `versionCheckHook`: "adds a `versionCheckPhase` … runs the main program of the derivation with a `--help` or `--version` argument, and checks that the `${version}` string is found"; use `nativeInstallCheckInputs = [ versionCheckHook ]; doInstallCheck = true;`.
- `meta.mainProgram`: "The name of the main binary for the package. This affects the binary `nix run` executes."
- `pkgsCross` names (lib/systems/examples.nix): `mingwW64`, `ucrt64`, `mingw32`, `aarch64-multiplatform`, `aarch64-multiplatform-musl`, `musl64`, `gnu64`, `aarch64-darwin`, `x86_64-freebsd`, `aarch64-freebsd`, `riscv64`, `wasi32`, `armv7l-hf-multiplatform`; there is no `x86_64-darwin` example. Manual: "The same pattern works for other targets by substituting the `pkgsCross.*` attribute and the emulator package (e.g. `wine` for `pkgsCross.mingwW64`)." [S33, S34, S35, S36, S37, S38, S39, S40]

## 5. Reproducibility

- `nix build --rebuild`: "Rebuild an already built package and compare the result to the existing store paths." No `--check` on the new-CLI page. Old CLI `nix-store --realise --check` / `nix-build --check`: "It rebuilds the specified derivation and checks whether the result is bitwise-identical with the existing outputs"; with `-K` "the new output path is left in /nix/store/name.check."; exit 104 = "The build succeeded in check mode but the resulting output is not binary reproducible." [S2 nix3-build, nix-store/realise]
- `diff-hook`: "Absolute path to an executable capable of diffing build results. The hook is executed if `run-diff-hook` is true, and the output of a build is known to not be the same." [S2 conf-file]
- `nix store verify`: "verifies the integrity of the store paths installables, or, if `--all` is given, the entire Nix store"; `--no-contents`, `--no-trust`, `--sigs-needed n`, `--substituter`; exit code = sum of 1 (corrupted) + 2 (untrusted) + 4 (other). [S2 nix3-store-verify]
- `nix hash path`: "print cryptographic hash of the NAR serialisation of a path"; `--algo {blake3,md5,sha1,sha256,sha512}`, `--base32`, `--sri` (SRI is default). [S2 nix3-hash-path]
- `nix path-info --json`: "store object info" `version` 3 with `path`, `narHash`, `narSize`, `references`, `ca`, `storeDir`, `deriver`, `registrationTime`, `ultimate` ("trusted because we built it ourselves"), `signatures`, `closureSize`; binary-cache variants add `downloadHash`, `downloadSize`, `closureDownloadSize`. [S2 store-object-info]
- nix-diff "explains why two Nix derivations differ" (derivation-level). [S41]
- reproducible.nixos.org minimal-ISO runtime report: "579 out of 582 (99.48%)" paths reproducible for `nixos.iso_minimal.x86_64-linux` on `nixos-unstable`; "Each build is run twice, at different times, on different hardware running different kernels." Page shows generation date 2025-02-09. [S42]
- `SOURCE_DATE_EPOCH` (stdenv setup.sh): `: "${SOURCE_DATE_EPOCH:=315532800}"`; comment: "315532800 = 1980-01-01 12:00:00. We use this date because python's wheel implementation uses zip archive and zip does not support dates going back to 1970." [S43]
- Go: "As of Go 1.21, the Go toolchain is perfectly reproducible"; "For Go programs that don't need `cgo`, a reproducible build is as simple as compiling with `CGO_ENABLED=0 go build -trimpath`." buildGoModule supplies `-trimpath` and `-buildid=` by default; nixpkgs makes no explicit bit-reproducibility promise beyond that module.nix comment. [S44, S34]

## 6. Nix in GitHub Actions (tags/SHAs via git ls-remote; dates from GitHub releases)

| Action | Latest | Commit SHA | Date |
|---|---|---|---|
| DeterminateSystems/nix-installer-action | v23 | 3138316df39ed29be04236d7ffc686fa525866aa | 2026-09-09 |
| DeterminateSystems/determinate-nix-action | v3.22.5 | 8d87e8d5e5b8a8309d4281094560f127d9a265f1 | 2026-09-18 |
| DeterminateSystems/flakehub-cache-action | v3.22.5 | 83282a8aef353db1d659d3bacf4a28b6683de0b3 | 2026-09-18 |
| DeterminateSystems/magic-nix-cache-action | v15 | 84c0677f58dcedf3b91f8223ce36a9ea5b3c84b7 | 2026-09-09 |
| DeterminateSystems/update-flake-lock | v29 | da03c0f078bc4b2c37ee4f7e072d34bf8f188bb3 | 2026-09-09 |
| DeterminateSystems/flake-checker-action | v14 | 786422608c7bded2bbc9741ad9f91356842bf520 | 2026-09-09 |
| cachix/install-nix-action | v31.11.1 (`v31` → same commit) | 13d8dd58da0234aa297dedd986986ccb8e7f3e24 | 2026-08-13 |
| cachix/cachix-action | v17 | 38b082610b782e7e93e209c35fd730d399dee866 | 2026-03-18 |
| nixbuild/nix-quick-install-action | v35 | 9f63be77f412a248c9d9a65a4c82cf066cdf8f0c | 2026-06-17 |
| nix-community/cache-nix-action | v7.0.2 (`v7` → same commit) | 7df957e333c1e5da7721f60227dbba6d06080569 | 2026-01-30 |

- **nix-installer-action:** inputs `determinate` ("Whether to install Determinate Nix and log in to FlakeHub for private Flakes and binary caches.", default true), `flakehub` ("Deprecated. Implies `determinate`."), `extra-conf`, `github-token` (default `${{ github.token }}`), `nix-package-url`, `source-tag`/`source-url`, `kvm`, `trust-runner-user`, `start-daemon`, `reinstall`. README defers FlakeHub Cache to determinate-nix-action. [S14]
- **determinate-nix-action / FlakeHub Cache:** "GitHub Actions are tagged with the specific version, like `v3.5.2`, with a moving `v3` tag"; "If you use FlakeHub, you need to add a `permissions` block … or else Determinate Nix can't authenticate with FlakeHub or FlakeHub Cache." Official snippet: `permissions: {contents: read, id-token: write}` then `determinate-nix-action@v3` + `flakehub-cache-action@main`. FlakeHub Cache "is available only on paid plans." [S15, S45]
- **magic-nix-cache-action:** 2025-01-21 post (Graham Christensen): "the API backing Magic Nix Cache's free CI cache in GitHub Actions will be shut down on February 1st, 2025." and "Any builds still using the Magic Nix Cache Action will begin to fail once GitHub proceeds with decommissioning the v1 cache API." 2025-06-13 post (Luc Perkins, "Bringing back the Magic Nix Cache Action"): revived with a reverse-engineered client for GitHub's new cache API; "The API could change at any time, which could in turn make the new approach nonviable"; recommends FlakeHub Cache. v10 (2025-06-10) note: "notify users about EOL of magic nix cache on GHA". Today the repo is not archived, v15 shipped 2026-09-09, README: "You can upgrade to FlakeHub Cache and get one month free using the coupon code `FHC`." [S46, S47, S48]
- **cachix/install-nix-action:** inputs `extra_nix_config` ("Gets appended to `/etc/nix/nix.conf`"), `github_access_token`, `install_url`, `install_options`, `nix_path` ("Set NIX_PATH environment variable."), `enable_kvm` (true), `set_as_trusted_user` (true). Script at v31.11.1: appends `experimental-features = nix-command flakes` unless you set it, `always-allow-substitutes = true`, `trusted-users = root $USER`, `access-tokens = github.com=$GITHUB_TOKEN` by default ("Token-less access is subject to lower rate limits."), installer flag `--no-channel-add`. [S12, S49]
- **nix-quick-install-action:** "Installs in ≈ 1 second on Linux, ≈ 5 seconds on MacOS"; "Quickly installs Nix in unprivileged single-user mode"; inputs `nix_version` (each release ships a fixed set), `nix_conf`, `github_access_token` (default `${{ github.token }}`), `nix_on_tmpfs`, `enable_kvm`; for Nix > 2.13 "experimental-features = nix-command flakes" and "accept-flake-config = true" are always set. master README lists 2.28.7, 2.29.4, 2.30.5, 2.31.5, 2.32.8, 2.33.6, 2.34.7, 2.3.18. [S13, S50]
- **cache-nix-action:** "A GitHub Action to restore and save Nix store paths using GitHub Actions cache."; example `primary-key: nix-${{ runner.os }}-${{ hashFiles('**/flake.lock') }}`, `restore-prefixes-first-match`, `gc-max-store-size-linux: 1G`, `purge: true`; "A repository can have up to 10GB of caches."; uses "the new cache service (v2) APIs"; pairs with nix-quick-install-action. [S51]
- **Official installer and releases.nixos.org:** nixos.org/download shows 2.35.2 and `curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon`. HEAD requests under `https://releases.nixos.org/nix/nix-2.35.2/` return 200 for `nix-2.35.2-<system>.tar.xz` with system ∈ {x86_64-linux, aarch64-linux, i686-linux, armv7l-linux, riscv64-linux, x86_64-darwin, aarch64-darwin}, for each sibling `.sha256` (x86_64-linux: `0c3960a9792331a22081c3c7a5d8465db9b17c50b3acdf18587fa4c6f2cb1158`), and for `install` + `install.sha256`. No `nix/latest/` exists (404). The index page is JavaScript-rendered. [S52, S3]
- **Docker `nixos/nix`:** tags `latest`, `2.35.2`, `2.35.2-amd64`, `2.35.2-arm64`, `2.35.1`, `2.35.0`, `2.34.8`, …; Hub: "sandboxing is disabled by default in the container". Built from NixOS/nix `docker.nix`, which includes `gitMinimal`, `bashInteractive`, `coreutils-full`, `gnutar`, `gzip`, `gnugrep`, `which`, `curl`, `less`, `wget`, `man`, `cacert`, `findutils`, `iana-etc`, `openssh`; baked nix.conf: `sandbox = false`, `build-users-group = "nixbld"`, cache.nixos.org key; no `experimental-features` (pass `--extra-experimental-features 'nix-command flakes'` or `NIX_CONFIG`). [S53, S54]
- **nix-github-actions:** "a library to turn Nix Flake attribute sets into Github Actions matrices." `githubActions = nix-github-actions.lib.mkGithubMatrix { checks = self.packages; };` or `{ inherit (self) checks; }`; restrict systems via `checks = nixpkgs.lib.getAttrs [ "x86_64-linux" "x86_64-darwin" ] self.checks;`; quickstart `nix run github:nix-community/nix-github-actions`; no tagged releases. [S55]
- **flake-checker-action:** checks that root nixpkgs inputs "Have been updated within the last 30 days", "Have the `NixOS` GitHub org as their owner", "Are from a supported Git branch"; inputs `flake-lock-path`, `check-outdated`, `check-owner`, `check-supported`, `nixpkgs-keys`, `ignore-missing-flake-lock`, `fail-mode` (false), `send-statistics` (true), `condition` (CEL). README's branch list still names 22.11/23.05-era branches. [S56]
- **update-flake-lock:** example `permissions: contents: write, id-token: write, issues: write, pull-requests: write`; inputs `token`, `pr-title`, `pr-labels`, `inputs`, `nix-options`, `path-to-flake-dir`, `sign-commits`, `pr-assignees`/`pr-reviewers`; "By providing a Personal Authentication Token, the PR is submitted in a way that bypasses this limitation." (Actions-opened PRs don't trigger CI; fine-grained PAT with Contents + Pull Requests read/write.) [S57]

## 7. Nixpkgs versioning rule (pkgs/README.md "Versioning", verbatim)

- "It _must_ start with a digit." Example: `"0.3.1rc2"` or `"0-unstable-1970-01-01"`.
- "If a package is a commit from a repository without a version assigned, then the `version` attribute _should_ be the latest upstream version preceding that commit, followed by `-unstable-` and the date of the (fetched) commit. The date _must_ be in `"YYYY-MM-DD"` format." Example `version = "2.2-unstable-2022-03-15"`.
- "If a project has no suitable preceding releases … then the latest upstream version in the above schema should be `0`." Example `version = "0-unstable-2022-03-15"`. [S58]

## 8. 2025–2026 announcements affecting flakes/CI

- No CLI/flakes stabilization in 2.34/2.35; `flakes`, `nix-command`, `fetch-tree` remain experimental; lock format still `"version": 7` (sections 1 and 3).
- 2.35: lazy source copying, `builtins.getFlake ./subflake`, SCP-like git URLs, GitHub fetcher rejects unknown params such as `tag`; 2.34: `lint-url-literals` stabilised, concurrent tarball cache, relative `file:` tarball paths rejected. [S2]
- "Determinate Nix 3.0" (March 2025) drew the Steering Committee statement: "in the absence of such a specification, Nix is the specification." [S9]
- Tokens/rate limits: manual `access-tokens`: "Access tokens used to access protected GitHub, GitLab, or other locations requiring token-based authentication." Format `host=token`, e.g. `access-tokens = github.com=23ac...b289 gitlab.mycompany.com=PAT:A123Bp_Cd..EfG`; host may include a path (`github.com/org=token`). The manual never mentions rate limits; install-nix-action's script does ("Token-less access is subject to lower rate limits."), and all three installers inject `${{ github.token }}` by default. [S2 conf-file, S59, S12]
- Tarball inputs: "Lockable HTTP Tarball Protocol" (`Link … rel="immutable"`; tarball `lastModified` is "the timestamp of the newest file inside the tarball"); "supported by Gitea since version 1.22.1 and by Forgejo since versions 7.0.4/8.0.0". Official templates now use `https://channels.nixos.org/<channel>/nixexprs.tar.zst`. [S2 tarball-fetcher, S21]

## Could NOT verify

1. Exact GitHub publish timestamp of Nix 2.35.2 (release page failed to render); tarball Last-Modified 2026-08-12 used instead.
2. Which Determinate Nix version nix-installer-action v23 installs with `determinate: true` (delegates to nix-installer; unstated).
3. Whether Determinate Nix or Lix enable flakes by default; Lix's flake status.
4. nix-github-actions' system-to-runner map (`githubPlatforms` not found in lib.nix at master).
5. NixOS 25.11 end-of-support date.
6. Freshness of reproducible.nixos.org (page shows 2025-02-09).
7. flake-checker-action's real supported-branch list (README looks stale).
8. Any official statement on `pkgsCross` Darwin targets for Go from Linux; only mingwW64 + wine is documented.
9. nix.dev offers no formatter or flake-utils/flake-parts recommendation beyond the quoted sentences.
10. A literal manual sentence that flakes cannot see git tags; established from the attribute list and code.

## Sources (all accessed 2026-09-24)

- S1 https://github.com/NixOS/nix (git ls-remote tags)
- S2 Nix manual https://nix.dev/manual/nix/latest/ — pages: release-notes/rl-2.35, release-notes/rl-2.34, release-notes/index, development/experimental-features, command-ref/new-cli/nix3-flake (source src/nix/flake.md), nix3-flake-check (src/nix/flake-check.md), nix3-flake-lock, nix3-flake-update, nix3-build, nix3-store-verify, nix3-hash-path, nix3-path-info, command-ref/conf-file, command-ref/nix-store/realise, language/builtins, protocols/tarball-fetcher, protocols/json/store-object-info
- S3 https://releases.nixos.org/nix/nix-2.35.2/ (HEAD requests)
- S4 NixOS/nix master `.version` and `doc/manual/rl-next` (shallow clone, HEAD 2026-09-23)
- S5 https://discourse.nixos.org/t/nix-2-35-0-released/78914
- S6 https://github.com/NixOS/rfcs/blob/master/rfcs/0106-nix-release-schedule.md
- S7 https://github.com/NixOS/rfcs/pull/136
- S8 https://discourse.nixos.org/t/stabilising-the-new-nix-command-line-interface/35531
- S9 https://discourse.nixos.org/t/on-flakes-and-determinate-nix/61390
- S10 https://git.lix.systems/api/v1/repos/lix-project/lix/tags and https://lix.systems/blog/
- S11 https://github.com/DeterminateSystems/nix-src (README, releases/tag/v3.22.5)
- S12 https://raw.githubusercontent.com/cachix/install-nix-action/v31.11.1/install-nix.sh
- S13 https://raw.githubusercontent.com/nixbuild/nix-quick-install-action/v35/action.yml
- S14 https://github.com/DeterminateSystems/nix-installer-action (README, v23 action.yml)
- S15 https://github.com/DeterminateSystems/determinate-nix-action
- S16 https://github.com/NixOS/nixpkgs (git ls-remote heads)
- S17 https://nixos.org/manual/nixos/stable/release-notes and nixos/doc/manual/release-notes/rl-2605.section.md
- S18 https://github.com/NixOS/rfcs/blob/master/rfcs/0080-nixos-release-schedule.md
- S19 https://nix.dev/concepts/faq.html
- S20 https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md
- S21 https://github.com/NixOS/templates (go-hello/flake.nix, trivial/flake.nix, README)
- S22 nixpkgs `pkgs/top-level/all-packages.nix` and `pkgs/development/compilers/go/{1.25,1.26,1.27}.nix` on nixos-unstable, nixos-26.05, nixos-25.11
- S23 https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/go/README.md
- S24 https://github.com/NixOS/nix/blob/master/src/libexpr/primops/fetchTree.cc
- S25 https://github.com/NixOS/nix/blob/master/src/libfetchers/git.cc
- S26 https://github.com/NixOS/nix/blob/master/src/libflake/flake.cc
- S27 https://github.com/NixOS/nixfmt (README)
- S28 https://github.com/NixOS/nix/blob/master/src/nix/flake.cc
- S29 https://github.com/NixOS/nixpkgs/blob/master/lib/systems/flake-systems.nix
- S30 https://nix.dev/concepts/flakes.html
- S31 https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/aliases.nix and pkgs/by-name/ni/{nixfmt,nixfmt-tree}/package.nix
- S32 https://github.com/NixOS/nixfmt/releases
- S33 https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/go.section.md (rendered at https://nixos.org/manual/nixpkgs/unstable/#sec-language-go)
- S34 https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/go/module.nix
- S35 https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/compilers/go/1.26.nix
- S36 https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/make-derivation.nix
- S37 https://github.com/NixOS/nixpkgs/blob/master/doc/stdenv/cross-compilation.chapter.md
- S38 https://github.com/NixOS/nixpkgs/blob/master/doc/hooks/versionCheckHook.section.md
- S39 https://github.com/NixOS/nixpkgs/blob/master/doc/stdenv/meta.chapter.md
- S40 https://github.com/NixOS/nixpkgs/blob/master/lib/systems/examples.nix
- S41 https://github.com/Gabriella439/nix-diff
- S42 https://reproducible.nixos.org/ and https://reproducible.nixos.org/nixos-iso-minimal-runtime/
- S43 https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/setup.sh
- S44 https://go.dev/blog/rebuild
- S45 https://docs.determinate.systems/flakehub/cache/
- S46 https://determinate.systems/blog/magic-nix-cache-free-tier-eol/
- S47 https://determinate.systems/blog/bringing-back-magic-nix-cache-action/
- S48 https://github.com/DeterminateSystems/magic-nix-cache-action (README, releases v10/v15)
- S49 https://github.com/cachix/install-nix-action (README, action.yml)
- S50 https://github.com/nixbuild/nix-quick-install-action (README)
- S51 https://github.com/nix-community/cache-nix-action
- S52 https://nixos.org/download/
- S53 https://hub.docker.com/r/nixos/nix (+ v2 tags API)
- S54 https://github.com/NixOS/nix/blob/master/docker.nix
- S55 https://github.com/nix-community/nix-github-actions
- S56 https://github.com/DeterminateSystems/flake-checker-action
- S57 https://github.com/DeterminateSystems/update-flake-lock
- S58 https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#versioning
- S59 https://github.com/NixOS/nix/blob/master/src/libfetchers/include/nix/fetchers/fetch-settings.hh

Raw sources downloaded for verbatim quoting: /tmp/claude-1000/-tmp-release-experiment/b6dd3ee4-f98f-46e1-b2e4-780cd93d4ed7/scratchpad/src/ (flake.md, flake-check.md, go.section.md, module.nix, setup.sh, docker.nix, pkgs-README.md, CONTRIBUTING.md, all-packages-*.nix).
