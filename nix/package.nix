{
  lib,
  buildGoModule,
  versionCheckHook,
  src,
  version,
  commit,
  date,
}:
buildGoModule {
  pname = "relver";
  inherit version src;

  # No third-party modules; the SBOM of this binary is the Go standard library.
  vendorHash = null;
  env.CGO_ENABLED = 0;

  # -trimpath and -buildid= are added by buildGoModule; together with
  # CGO_ENABLED=0 this makes the binary bit-for-bit reproducible.
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.commit=${commit}"
    "-X main.date=${date}"
  ];

  # `relver version` must report exactly the version derived from CHANGELOG.md.
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
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
