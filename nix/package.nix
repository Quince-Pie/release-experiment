# Builds relver with the upstream Go toolchain. Deliberately not
# buildGoModule: the project has no module dependencies, and a release
# artifact should be produced by an auditable, minimal recipe whose output
# depends only on the Go version, the source and the flags below.
#
# `goos`/`goarch` select a foreign target (Go cross-compiles without any C
# toolchain because CGO is disabled); the native build additionally runs
# vet, the tests and the version self-check.
{
  lib,
  stdenvNoCC,
  goToolchain,
  versionCheckHook,
  src,
  version,
  commit,
  date,
  goos ? null,
  goarch ? null,
}:
let
  native = goos == null;
  exe = "relver" + lib.optionalString (goos == "windows") ".exe";
in
stdenvNoCC.mkDerivation {
  pname = "relver" + lib.optionalString (!native) "-${goos}-${goarch}";
  inherit version src;

  nativeBuildInputs = [ goToolchain ] ++ lib.optional native versionCheckHook;

  env = {
    CGO_ENABLED = "0";
    GO111MODULE = "on";
    GOTOOLCHAIN = "local";
    GOPROXY = "off";
    GOSUMDB = "off";
    # -trimpath removes build paths; -buildvcs=false keeps git metadata out
    # of the binary (the commit is passed explicitly below) so a checkout with
    # or without .git links identically; -mod=mod with GOPROXY=off works
    # because there are no dependencies to fetch.
    GOFLAGS = "-trimpath -buildvcs=false -mod=mod";
  }
  // lib.optionalAttrs (!native) {
    GOOS = goos;
    GOARCH = goarch;
  };

  # -buildid= makes the build ID empty instead of content-derived from
  # absolute paths; -s -w drop the symbol table and DWARF.
  ldflags = "-s -w -buildid= -X main.version=${version} -X main.commit=${commit} -X main.date=${date}";

  configurePhase = ''
    runHook preConfigure
    export HOME="$TMPDIR" GOCACHE="$TMPDIR/go-cache" GOPATH="$TMPDIR/go"
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    go build -ldflags "$ldflags" -o "${exe}" ./cmd/relver
    runHook postBuild
  '';

  doCheck = native;
  checkPhase = ''
    runHook preCheck
    go vet ./...
    go test ./...
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 "${exe}" "$out/bin/${exe}"
    runHook postInstall
  '';

  # The bytes the Go linker wrote are the release artifact. Nix's default
  # fixup would run strip/patchelf on native ELF binaries (rewriting the
  # section layout) but skip foreign ones, which alone makes builds differ
  # between build hosts.
  dontFixup = true;

  doInstallCheck = native;
  versionCheckProgramArg = "version";

  meta = {
    description = "Semantic Versioning 2.0.0 tool; the release artifact of release-experiment";
    homepage = "https://github.com/Quince-Pie/release-experiment";
    changelog = "https://github.com/Quince-Pie/release-experiment/blob/main/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "relver";
    platforms = lib.platforms.unix ++ lib.platforms.windows;
  };
}
