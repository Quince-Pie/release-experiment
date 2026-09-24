# Packs cross-compiled binaries into the archives that are published as
# release assets, plus a GNU-format SHA256SUMS. Everything is deterministic:
# fixed mtimes from the commit timestamp, sorted members, no owner metadata,
# gzip without name/timestamp. The release workflow proves this with
# `nix build --rebuild`.
{
  lib,
  stdenvNoCC,
  gnutar,
  gzip,
  zip,
  pname,
  version,
  epoch,
  license,
  binaries, # list of { goos; goarch; drv; }
}:
stdenvNoCC.mkDerivation {
  name = "${pname}-release-assets-${version}";
  nativeBuildInputs = [
    gnutar
    gzip
    zip
  ];
  dontUnpack = true;
  buildCommand = ''
    export SOURCE_DATE_EPOCH=${toString epoch}
    export TZ=UTC
    export LC_ALL=C
    mkdir -p "$out"
    ${lib.concatMapStringsSep "\n" (
      b:
      let
        exe = if b.goos == "windows" then "${pname}.exe" else pname;
        base = "${pname}_${version}_${b.goos}_${b.goarch}";
      in
      ''
        stage="$(mktemp -d)"
        chmod 755 "$stage"
        install -m755 "${b.drv}/bin/${exe}" "$stage/${exe}"
        install -m644 "${license}" "$stage/LICENSE"
        find "$stage" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
        ${
          if b.goos == "windows" then
            ''
              (cd "$stage" && find . -type f | sort | zip -X -q -D "$out/${base}.zip" -@)
            ''
          else
            ''
              tar --format=ustar --sort=name --mtime="@$SOURCE_DATE_EPOCH" \
                --owner=0 --group=0 --numeric-owner \
                -C "$stage" -cf - . | gzip -n -9 > "$out/${base}.tar.gz"
            ''
        }
      ''
    ) binaries}
    (cd "$out" && sha256sum $(ls | sort) > ../SHA256SUMS && mv ../SHA256SUMS .)
  '';
}
