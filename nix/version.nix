# Derives the project version from CHANGELOG.md, the single source of truth.
#
# Rules:
#   * The topmost "## [X.Y.Z] - YYYY-MM-DD" heading is the latest release.
#   * If the "## [Unreleased]" section is empty, this checkout *is* that
#     release and the version is X.Y.Z.
#   * Otherwise the checkout is a development snapshot and gets a Go-style
#     pseudo-version that sorts after the latest release and before the next
#     one (https://go.dev/ref/mod#pseudo-versions):
#       X.Y.(Z+1)-0.YYYYMMDDHHMMSS-<12 hex>    after a normal release
#       X.Y.Z-pre.0.YYYYMMDDHHMMSS-<12 hex>    after a pre-release
#       0.0.0-YYYYMMDDHHMMSS-<12 hex>          before any release
#     These are valid SemVer 2.0.0 strings, so every consumer can order them.
#
# A flake cannot see git tags, so the tag is validated against this value by
# the release workflow instead of being read here.
{ lib, self }:
let
  lines = lib.splitString "\n" (builtins.readFile ../CHANGELOG.md);

  releaseHeading = "## [[]([0-9]+[.][0-9]+[.][0-9]+(-[0-9A-Za-z.-]+)?)[]] - [0-9]{4}-[0-9]{2}-[0-9]{2}( [[]YANKED[]])?";
  matchRelease = l: builtins.match releaseHeading l;
  releases = lib.filter (l: matchRelease l != null) lines;
  latest = if releases == [ ] then null else builtins.head (matchRelease (builtins.head releases));

  # Lines strictly between "## [Unreleased]" and the next "## " heading.
  unreleasedBody =
    (lib.foldl'
      (
        st: l:
        if st.state == 0 then
          (if l == "## [Unreleased]" then st // { state = 1; } else st)
        else if st.state == 1 then
          (if lib.hasPrefix "## " l then st // { state = 2; } else st // { acc = st.acc ++ [ l ]; })
        else
          st
      )
      {
        state = 0;
        acc = [ ];
      }
      lines
    ).acc;
  unreleasedEmpty = lib.all (l: builtins.match "[[:space:]]*" l != null) unreleasedBody;

  timestamp = self.lastModifiedDate or "19700101000000";
  shortHash =
    if self ? rev then
      builtins.substring 0 12 self.rev
    else if self ? dirtyShortRev then
      self.dirtyShortRev
    else
      "unknown";

  bumpPatch =
    v:
    let
      m = builtins.match "([0-9]+)[.]([0-9]+)[.]([0-9]+)" v;
    in
    "${builtins.elemAt m 0}.${builtins.elemAt m 1}.${toString (lib.toInt (builtins.elemAt m 2) + 1)}";

  pseudo =
    if latest == null then
      "0.0.0-${timestamp}-${shortHash}"
    else if lib.hasInfix "-" latest then
      "${latest}.0.${timestamp}-${shortHash}"
    else
      "${bumpPatch latest}-0.${timestamp}-${shortHash}";

  isRelease = latest != null && unreleasedEmpty;

  # "20260924051230" -> "2026-09-24T05:12:30Z"
  isoDate =
    let
      s = n: l: builtins.substring n l timestamp;
    in
    "${s 0 4}-${s 4 2}-${s 6 2}T${s 8 2}:${s 10 2}:${s 12 2}Z";
in
{
  inherit
    latest
    unreleasedEmpty
    isRelease
    pseudo
    ;
  version = if isRelease then latest else pseudo;
  commit = self.rev or self.dirtyRev or "unknown";
  date = isoDate;
  epoch = self.lastModified or 0;
}
