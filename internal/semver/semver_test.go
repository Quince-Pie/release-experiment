package semver

import (
	"errors"
	"slices"
	"testing"
)

// The ordered examples are taken verbatim from SemVer 2.0.0 items 11.2 and 11.4.
var specOrder = []string{
	"1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta",
	"1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0",
	"2.0.0", "2.1.0", "2.1.1",
}

func TestSpecPrecedence(t *testing.T) {
	vs := make([]Version, len(specOrder))
	for i, s := range specOrder {
		v, err := Parse(s)
		if err != nil {
			t.Fatalf("Parse(%q): %v", s, err)
		}
		if got := v.String(); got != s {
			t.Errorf("String() = %q, want round-trip %q", got, s)
		}
		vs[i] = v
	}
	for i := 1; i < len(vs); i++ {
		if c := Compare(vs[i-1], vs[i]); c != -1 {
			t.Errorf("Compare(%s, %s) = %d, want -1", vs[i-1], vs[i], c)
		}
		if c := Compare(vs[i], vs[i-1]); c != 1 {
			t.Errorf("Compare(%s, %s) = %d, want 1", vs[i], vs[i-1], c)
		}
	}
	shuffled := slices.Clone(vs)
	slices.Reverse(shuffled)
	slices.SortFunc(shuffled, Compare)
	if !slices.EqualFunc(shuffled, vs, func(a, b Version) bool { return Compare(a, b) == 0 }) {
		t.Errorf("sort order differs from specification order")
	}
}

func TestBuildMetadataIgnored(t *testing.T) {
	a, _ := Parse("1.0.0+20130313144700")
	b, _ := Parse("1.0.0+exp.sha.5114f85")
	c, _ := Parse("1.0.0")
	if Compare(a, b) != 0 || Compare(a, c) != 0 {
		t.Errorf("build metadata must not affect precedence")
	}
	if len(a.Build) != 1 || len(b.Build) != 3 {
		t.Errorf("build metadata not preserved: %v %v", a.Build, b.Build)
	}
}

func TestInvalid(t *testing.T) {
	for _, s := range []string{
		"", "1", "1.0", "01.0.0", "1.01.0", "1.0.01", "1.0.0-01", "1.0.0-", "1.0.0+",
		"v1.0.0", "1.0.0-alpha..1", "1.0.0-alpha_1", "1.0.0 ", " 1.0.0", "1.0.0-rc.1+",
		"2026.09.24", // zero-padded CalVer: leading zeros are forbidden
	} {
		if _, err := Parse(s); !errors.Is(err, ErrInvalid) {
			t.Errorf("Parse(%q) = %v, want ErrInvalid", s, err)
		}
	}
}

func TestValidEdgeCases(t *testing.T) {
	for _, s := range []string{
		"0.0.0", "1.0.0-0", "1.0.0-0.3.7", "1.0.0-x.7.z.92", "1.0.0-x-y-z.--",
		"1.0.0-alpha+001", "1.0.0-beta+exp.sha.5114f85", "1.0.0--", "2026.9.24",
		"1.0.0-0A", "18446744073709551615.0.0",
	} {
		if _, err := Parse(s); err != nil {
			t.Errorf("Parse(%q): unexpected error %v", s, err)
		}
	}
}

func TestNext(t *testing.T) {
	v, _ := Parse("1.2.3-rc.1+build.9")
	for _, tc := range []struct {
		part Part
		want string
	}{{Major, "2.0.0"}, {Minor, "1.3.0"}, {Patch, "1.2.4"}} {
		if got := v.Next(tc.part).String(); got != tc.want {
			t.Errorf("Next(%v) = %q, want %q", tc.part, got, tc.want)
		}
	}
	if _, err := ParsePart("mayor"); err == nil {
		t.Error("ParsePart accepted an unknown part")
	}
}
