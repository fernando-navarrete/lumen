#!/bin/sh
# Release gate for a vX.Y.Z tag. Fails unless pubspec.yaml's version and the tag agree, and
# CHANGELOG.md has a non-empty `## X.Y.Z` section; prints that section on stdout.
# Usage: tool/release_notes.sh <tag>   (run from the repo root)
set -eu

tag="${1:-}"
if ! printf '%s\n' "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "error: '$tag' is not a vX.Y.Z tag" >&2
  exit 1
fi
version="${tag#v}"

pubspec_version=$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml | head -n 1 | tr -d '\r')
if [ "$pubspec_version" != "$version" ]; then
  {
    echo "error: version mismatch"
    echo "  tag:          $version"
    echo "  pubspec.yaml: ${pubspec_version:-<not found>}"
  } >&2
  exit 1
fi

notes=$(awk -v heading="## $version" '
  {
    line = $0
    sub(/[ \t\r]+$/, "", line)
  }
  found && /^## / { exit }
  found { print line; next }
  line == heading { found = 1 }
' CHANGELOG.md | awk '
  NF { started = 1 }
  started { lines[++n] = $0 }
  END {
    while (n > 0 && lines[n] !~ /[^ \t]/) n--
    for (i = 1; i <= n; i++) print lines[i]
  }
')

if [ -z "$notes" ]; then
  echo "error: CHANGELOG.md has no non-empty '## $version' section" >&2
  exit 1
fi

printf '%s\n' "$notes"
