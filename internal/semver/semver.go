// Package semver parses and orders version strings exactly as specified by
// Semantic Versioning 2.0.0 (https://semver.org/spec/v2.0.0.html).
//
// The grammar is the specification's own regular expression; precedence
// follows item 11 of the specification. Build metadata is parsed but ignored
// for ordering.
package semver

import (
	"cmp"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// Version is a parsed SemVer 2.0.0 version.
type Version struct {
	Major, Minor, Patch uint64
	// PreRelease holds the dot-separated pre-release identifiers, if any.
	PreRelease []string
	// Build holds the dot-separated build metadata identifiers, if any.
	Build []string
}

// ErrInvalid is returned (wrapped) by Parse for strings that are not valid
// SemVer 2.0.0 versions.
var ErrInvalid = errors.New("invalid semantic version")

// re is the regular expression published in the SemVer 2.0.0 FAQ, using
// numbered capture groups: 1 major, 2 minor, 3 patch, 4 pre-release, 5 build.
var re = regexp.MustCompile(`^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$`)

// Parse parses s as a SemVer 2.0.0 version. A leading "v" is not part of
// the grammar and is rejected; strip it first if you are parsing git tags.
func Parse(s string) (Version, error) {
	m := re.FindStringSubmatch(s)
	if m == nil {
		return Version{}, fmt.Errorf("%w: %q", ErrInvalid, s)
	}
	var v Version
	var err error
	for i, dst := range []*uint64{&v.Major, &v.Minor, &v.Patch} {
		if *dst, err = strconv.ParseUint(m[i+1], 10, 64); err != nil {
			return Version{}, fmt.Errorf("%w: %q: %v", ErrInvalid, s, err)
		}
	}
	if m[4] != "" {
		v.PreRelease = strings.Split(m[4], ".")
	}
	if m[5] != "" {
		v.Build = strings.Split(m[5], ".")
	}
	return v, nil
}

// String renders v in canonical form.
func (v Version) String() string {
	var b strings.Builder
	fmt.Fprintf(&b, "%d.%d.%d", v.Major, v.Minor, v.Patch)
	if len(v.PreRelease) > 0 {
		b.WriteByte('-')
		b.WriteString(strings.Join(v.PreRelease, "."))
	}
	if len(v.Build) > 0 {
		b.WriteByte('+')
		b.WriteString(strings.Join(v.Build, "."))
	}
	return b.String()
}

// Compare orders a and b by SemVer precedence, returning -1, 0 or +1.
// Build metadata does not participate (spec item 10).
func Compare(a, b Version) int {
	if c := cmp.Compare(a.Major, b.Major); c != 0 {
		return c
	}
	if c := cmp.Compare(a.Minor, b.Minor); c != 0 {
		return c
	}
	if c := cmp.Compare(a.Patch, b.Patch); c != 0 {
		return c
	}
	return comparePreRelease(a.PreRelease, b.PreRelease)
}

// comparePreRelease implements spec item 11.3 and 11.4.
func comparePreRelease(a, b []string) int {
	switch {
	case len(a) == 0 && len(b) == 0:
		return 0
	case len(a) == 0: // a normal version has higher precedence than a pre-release
		return 1
	case len(b) == 0:
		return -1
	}
	for i := range min(len(a), len(b)) {
		if c := compareIdentifier(a[i], b[i]); c != 0 {
			return c
		}
	}
	// A larger set of pre-release fields has a higher precedence than a
	// smaller set, if all of the preceding identifiers are equal.
	return cmp.Compare(len(a), len(b))
}

// compareIdentifier orders two pre-release identifiers: numeric identifiers
// compare numerically, alphanumeric identifiers lexically in ASCII order, and
// numeric identifiers always have lower precedence than alphanumeric ones.
func compareIdentifier(x, y string) int {
	nx, xNum := strconv.ParseUint(x, 10, 64)
	ny, yNum := strconv.ParseUint(y, 10, 64)
	switch {
	case xNum == nil && yNum == nil:
		return cmp.Compare(nx, ny)
	case xNum == nil:
		return -1
	case yNum == nil:
		return 1
	default:
		return strings.Compare(x, y)
	}
}

// Part names a component of the version core.
type Part int

// The bumpable parts of a version core.
const (
	Major Part = iota
	Minor
	Patch
)

// ParsePart parses "major", "minor" or "patch".
func ParsePart(s string) (Part, error) {
	switch s {
	case "major":
		return Major, nil
	case "minor":
		return Minor, nil
	case "patch":
		return Patch, nil
	}
	return 0, fmt.Errorf("unknown version part %q (want major, minor or patch)", s)
}

// Next returns the next version after v when part is incremented, with any
// pre-release and build metadata removed (spec items 6, 7 and 8).
func (v Version) Next(part Part) Version {
	n := Version{Major: v.Major, Minor: v.Minor, Patch: v.Patch}
	switch part {
	case Major:
		n.Major, n.Minor, n.Patch = n.Major+1, 0, 0
	case Minor:
		n.Minor, n.Patch = n.Minor+1, 0
	case Patch:
		n.Patch++
	}
	return n
}
