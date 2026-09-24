// Command relver validates and orders Semantic Versioning 2.0.0 strings and
// reports its own build provenance. It is the release artifact of this
// repository, which exists to demonstrate a verifiable release process.
package main

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"runtime"
	"runtime/debug"
	"slices"
	"strings"

	"github.com/Quince-Pie/release-experiment/internal/semver"
)

// These are set at build time with -ldflags "-X main.version=..." because a
// Nix build has no .git directory for the toolchain to read VCS data from.
var (
	version = "0.0.0-unknown"
	commit  = "unknown"
	date    = "unknown"
)

const usage = `relver - Semantic Versioning 2.0.0 tool

Usage:
  relver version                      print build information
  relver check VERSION...             validate versions (exit 1 on the first invalid one)
  relver compare A B                  print -1, 0 or 1 by precedence
  relver sort [-r]                    sort versions read from stdin, one per line
  relver next {major|minor|patch} VERSION
                                      print the next version core

Versions are bare (no leading "v"); build metadata is accepted but ignored
for ordering, exactly as the specification requires.
`

func main() {
	if err := run(os.Args[1:], os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "relver:", err)
		if errors.Is(err, errUsage) {
			fmt.Fprint(os.Stderr, usage)
			os.Exit(2)
		}
		os.Exit(1)
	}
}

var errUsage = errors.New("usage error")

func run(args []string, stdin io.Reader, stdout io.Writer) error {
	if len(args) == 0 {
		return errUsage
	}
	switch cmd, rest := args[0], args[1:]; cmd {
	case "version", "--version", "-v":
		printVersion(stdout)
		return nil
	case "check":
		if len(rest) == 0 {
			return fmt.Errorf("%w: check needs at least one version", errUsage)
		}
		for _, s := range rest {
			if _, err := semver.Parse(s); err != nil {
				return err
			}
		}
		return nil
	case "compare":
		if len(rest) != 2 {
			return fmt.Errorf("%w: compare needs exactly two versions", errUsage)
		}
		a, err := semver.Parse(rest[0])
		if err != nil {
			return err
		}
		b, err := semver.Parse(rest[1])
		if err != nil {
			return err
		}
		_, err = fmt.Fprintln(stdout, semver.Compare(a, b))
		return err
	case "sort":
		reverse := false
		switch {
		case len(rest) == 0:
		case len(rest) == 1 && rest[0] == "-r":
			reverse = true
		default:
			return fmt.Errorf("%w: sort accepts only -r", errUsage)
		}
		return sortVersions(stdin, stdout, reverse)
	case "next":
		if len(rest) != 2 {
			return fmt.Errorf("%w: next needs a part and a version", errUsage)
		}
		part, err := semver.ParsePart(rest[0])
		if err != nil {
			return fmt.Errorf("%w: %v", errUsage, err)
		}
		v, err := semver.Parse(rest[1])
		if err != nil {
			return err
		}
		_, err = fmt.Fprintln(stdout, v.Next(part))
		return err
	case "help", "-h", "--help":
		_, err := io.WriteString(stdout, usage)
		return err
	default:
		return fmt.Errorf("%w: unknown command %q", errUsage, cmd)
	}
}

func sortVersions(r io.Reader, w io.Writer, reverse bool) error {
	var vs []semver.Version
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		v, err := semver.Parse(line)
		if err != nil {
			return err
		}
		vs = append(vs, v)
	}
	if err := sc.Err(); err != nil {
		return err
	}
	slices.SortStableFunc(vs, semver.Compare)
	if reverse {
		slices.Reverse(vs)
	}
	bw := bufio.NewWriter(w)
	for _, v := range vs {
		fmt.Fprintln(bw, v)
	}
	return bw.Flush()
}

func printVersion(w io.Writer) {
	goVersion := runtime.Version()
	if bi, ok := debug.ReadBuildInfo(); ok {
		goVersion = bi.GoVersion
	}
	fmt.Fprintf(w, "relver %s\n  commit:  %s\n  date:    %s\n  go:      %s\n  target:  %s/%s\n",
		version, commit, date, goVersion, runtime.GOOS, runtime.GOARCH)
}
