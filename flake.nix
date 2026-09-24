{
  description = "release-experiment: a reference, verifiable release process (artifact: relver)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # CHANGELOG.md is the single source of truth for the version.
      versionInfo = import ./nix/version.nix { inherit lib self; };

      # Only Go inputs feed the build, so documentation edits do not rebuild it.
      goSrc = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [
          ./go.mod
          ./cmd
          ./internal
        ];
      };

      # Release targets, named with Go's own GOOS/GOARCH vocabulary.
      targets = [
        {
          goos = "linux";
          goarch = "amd64";
        }
        {
          goos = "linux";
          goarch = "arm64";
        }
        {
          goos = "darwin";
          goarch = "amd64";
        }
        {
          goos = "darwin";
          goarch = "arm64";
        }
        {
          goos = "windows";
          goarch = "amd64";
        }
        {
          goos = "windows";
          goarch = "arm64";
        }
      ];

      packagesFor =
        pkgs:
        let
          relver = pkgs.callPackage ./nix/package.nix {
            src = goSrc;
            inherit (versionInfo) version commit date;
          };

          # Go cross-compiles without a C toolchain when CGO is off, so a
          # cross build is the native derivation with GOOS/GOARCH overridden
          # (buildGoModule pins env.GOOS/GOARCH from its Go package, hence
          # overrideAttrs rather than an argument). Tests cannot run for a
          # foreign target; they run in the native package.
          crossBinary =
            { goos, goarch }:
            relver.overrideAttrs (old: {
              pname = "relver-${goos}-${goarch}";
              env = old.env // {
                GOOS = goos;
                GOARCH = goarch;
              };
              doCheck = false;
              doInstallCheck = false;
              # `go install` places foreign-target binaries in bin/GOOS_GOARCH/.
              postInstall = ''
                if [ -d "$out/bin/${goos}_${goarch}" ]; then
                  mv "$out/bin/${goos}_${goarch}"/* "$out/bin/"
                  rmdir "$out/bin/${goos}_${goarch}"
                fi
              '';
            });

          crossPackages = lib.listToAttrs (
            map (t: {
              name = "relver-${t.goos}-${t.goarch}";
              value = crossBinary t;
            }) targets
          );

          release-assets = pkgs.callPackage ./nix/release-assets.nix {
            pname = "relver";
            inherit (versionInfo) version epoch;
            license = ./LICENSE;
            binaries = map (t: t // { drv = crossBinary t; }) targets;
          };
        in
        {
          inherit relver release-assets;
          default = relver;
        }
        // crossPackages;

      formatterFor =
        pkgs:
        pkgs.nixfmt-tree.override {
          runtimeInputs = [
            pkgs.go
            pkgs.shfmt
          ];
          settings = {
            formatter.gofmt = {
              command = "gofmt";
              options = [ "-w" ];
              includes = [ "*.go" ];
            };
            formatter.shfmt = {
              command = "shfmt";
              options = [
                "-w"
                "-i"
                "2"
                "-ci"
              ];
              includes = [ "*.sh" ];
            };
          };
        };

      # Tools shared by the dev shell and the app wrappers.
      releaseTools =
        pkgs: with pkgs; [
          git
          curl
          jq
          coreutils
          gnused
          gawk
          gnutar
          gzip
          cosign
        ];
    in
    {
      packages = forAllSystems packagesFor;

      formatter = forAllSystems formatterFor;

      checks = forAllSystems (
        pkgs:
        let
          p = packagesFor pkgs;
          formatter = formatterFor pkgs;
        in
        {
          inherit (p) relver release-assets;

          go-lint =
            pkgs.runCommand "go-lint"
              {
                nativeBuildInputs = [ pkgs.go ];
              }
              ''
                export HOME="$TMPDIR" GOCACHE="$TMPDIR/gocache" GOFLAGS=-mod=mod GOPROXY=off GOSUMDB=off GOTOOLCHAIN=local
                cd ${goSrc}
                unformatted="$(gofmt -l .)"
                if [ -n "$unformatted" ]; then
                  echo "gofmt: files need formatting:" "$unformatted" >&2
                  exit 1
                fi
                go vet ./...
                touch "$out"
              '';

          format =
            pkgs.runCommand "format-check"
              {
                nativeBuildInputs = [
                  formatter
                  pkgs.git
                ];
              }
              ''
                cp -r ${self} src
                chmod -R u+w src
                cd src
                treefmt --ci --no-cache --walk filesystem --tree-root "$PWD"
                touch "$out"
              '';

          changelog =
            pkgs.runCommand "changelog-lint"
              {
                nativeBuildInputs = [
                  p.relver
                  pkgs.bash
                  pkgs.gawk
                  pkgs.coreutils
                ];
              }
              ''
                cd ${self}
                bash scripts/changelog.sh lint
                touch "$out"
              '';

          shell-scripts =
            pkgs.runCommand "shell-scripts-lint"
              {
                nativeBuildInputs = [
                  pkgs.shellcheck
                  pkgs.shfmt
                ];
              }
              ''
                cd ${self}
                shellcheck --shell=bash --external-sources scripts/*.sh
                shfmt -d -i 2 -ci scripts
                touch "$out"
              '';

          workflows =
            pkgs.runCommand "workflows-lint"
              {
                nativeBuildInputs = [
                  pkgs.actionlint
                  pkgs.shellcheck
                  pkgs.zizmor
                ];
              }
              ''
                cd ${self}
                actionlint -color .github/workflows/*.yml
                zizmor --offline --persona pedantic --min-severity low .github/workflows
                touch "$out"
              '';
        }
      );

      devShells = forAllSystems (
        pkgs:
        let
          p = packagesFor pkgs;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ p.relver ];
            packages =
              releaseTools pkgs
              ++ (with pkgs; [
                gopls
                gotools
                govulncheck
                syft
                actionlint
                zizmor
                shellcheck
                shfmt
                (formatterFor pkgs)
              ])
              ++ [ p.relver ];
          };
        }
      );

      apps = forAllSystems (
        pkgs:
        let
          p = packagesFor pkgs;
          # Each script becomes an app with exactly the tools it needs, pinned
          # by flake.lock, so CI and maintainers run identical toolchains.
          mkApp =
            name: script: extraInputs:
            let
              drv = pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = releaseTools pkgs ++ [ p.relver ] ++ extraInputs;
                text = builtins.readFile script;
              };
            in
            {
              type = "app";
              program = lib.getExe drv;
              meta.description = "Run scripts/${baseNameOf script}";
            };
          zizmorOnline = pkgs.writeShellApplication {
            name = "audit-workflows";
            runtimeInputs = [ pkgs.zizmor ];
            text = ''
              exec zizmor --persona pedantic --min-severity low ''${GH_TOKEN:+--gh-token "$GH_TOKEN"} .github/workflows
            '';
          };
          vulncheck = pkgs.writeShellApplication {
            name = "vulncheck";
            runtimeInputs = [
              pkgs.go
              pkgs.govulncheck
            ];
            text = ''
              export GOFLAGS=-mod=mod GOTOOLCHAIN=local
              exec govulncheck ./...
            '';
          };
        in
        {
          default = {
            type = "app";
            program = lib.getExe p.relver;
            meta.description = "relver";
          };
          release = mkApp "release" ./scripts/release.sh [ ];
          changelog = mkApp "changelog" ./scripts/changelog.sh [ ];
          verify-tag = mkApp "verify-tag" ./scripts/verify-tag.sh [ ];
          verify = mkApp "verify-release" ./scripts/verify-release.sh [ ];
          github-release = mkApp "github-release" ./scripts/github-release.sh [ ];
          sbom = mkApp "sbom" ./scripts/sbom.sh [ pkgs.syft ];
          audit-workflows = {
            type = "app";
            program = lib.getExe zizmorOnline;
            meta.description = "zizmor with online audits";
          };
          vulncheck = {
            type = "app";
            program = lib.getExe vulncheck;
            meta.description = "govulncheck ./...";
          };
        }
      );

      lib = {
        inherit versionInfo;
      };
    };
}
