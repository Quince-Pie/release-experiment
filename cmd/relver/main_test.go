package main

import (
	"bytes"
	"errors"
	"strings"
	"testing"
)

func TestRun(t *testing.T) {
	for _, tc := range []struct {
		name  string
		args  []string
		stdin string
		want  string
		usage bool
		fails bool
	}{
		{name: "check ok", args: []string{"check", "1.0.0", "1.0.0-rc.1+b"}},
		{name: "check bad", args: []string{"check", "1.0.0", "v1.0.0"}, fails: true},
		{name: "compare", args: []string{"compare", "1.0.0-rc.1", "1.0.0"}, want: "-1\n"},
		{name: "sort", args: []string{"sort"}, stdin: "2.0.0\n1.0.0-rc.1\n\n1.0.0\n", want: "1.0.0-rc.1\n1.0.0\n2.0.0\n"},
		{name: "sort reverse", args: []string{"sort", "-r"}, stdin: "1.0.0\n2.0.0\n", want: "2.0.0\n1.0.0\n"},
		{name: "next", args: []string{"next", "minor", "1.2.3-rc.1"}, want: "1.3.0\n"},
		{name: "next bad part", args: []string{"next", "mayor", "1.2.3"}, usage: true},
		{name: "no args", args: nil, usage: true},
		{name: "unknown", args: []string{"frobnicate"}, usage: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var out bytes.Buffer
			err := run(tc.args, strings.NewReader(tc.stdin), &out)
			switch {
			case tc.usage:
				if !errors.Is(err, errUsage) {
					t.Fatalf("err = %v, want usage error", err)
				}
			case tc.fails:
				if err == nil || errors.Is(err, errUsage) {
					t.Fatalf("err = %v, want a non-usage error", err)
				}
			case err != nil:
				t.Fatalf("unexpected error: %v", err)
			}
			if got := out.String(); got != tc.want {
				t.Errorf("output = %q, want %q", got, tc.want)
			}
		})
	}
}

func TestVersionOutput(t *testing.T) {
	var out bytes.Buffer
	if err := run([]string{"version"}, nil, &out); err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(out.String(), "relver "+version+"\n") {
		t.Errorf("unexpected version output: %q", out.String())
	}
}
