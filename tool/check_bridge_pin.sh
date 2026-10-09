#!/bin/sh
# Bridge pin check, run first in `lint`. Reads the gogdl_flutter entry in pubspec.lock (or the file given as $1) and
# fails unless it is fetched from its GitHub mirror (or the remote given as $2), pinned by a vX.Y.Z tag, and that
# remote has the tag at the locked `resolved-ref` (the peeled commit when the tag is annotated). A clone then never
# pins a bridge it can't fetch, or fetches at another commit: `pub get --enforce-lockfile` fetches resolved-ref and
# would not notice a tag that moved on GitHub after the lock was written.
# Usage: tool/check_bridge_pin.sh [lockfile] [remote]   (run from the repo root)
set -eu

lock="${1:-pubspec.lock}"
remote="${2:-https://github.com/fernando-navarrete/gogdl_flutter.git}"

fields=$(awk '
function val(s) { sub(/^[^:]*: */, "", s); gsub(/"/, "", s); return s }
/^  [^ ]+:$/ { in_pkg = ($1 == "gogdl_flutter:"); next }
/^[^ ]/ { in_pkg = 0 }
in_pkg && /^      url: / { print "url=" val($0) }
in_pkg && /^      ref: / { print "ref=" val($0) }
in_pkg && /^      resolved-ref: / { print "sha=" val($0) }
' "$lock")

get() { printf '%s\n' "$fields" | sed -n "s/^$1=//p" | head -n 1; }
url=$(get url)
ref=$(get ref)
sha=$(get sha)

if [ -z "$url" ] || [ -z "$ref" ] || [ -z "$sha" ]; then
  echo "error: no gogdl_flutter git package with url, ref and resolved-ref in $lock" >&2
  exit 1
fi
if [ "$url" != "$remote" ]; then
  echo "error: gogdl_flutter in $lock is not fetched from $remote: $url" >&2
  exit 1
fi
case "$ref" in
  v[0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "error: gogdl_flutter in $lock is not pinned by a vX.Y.Z tag: $ref" >&2; exit 1 ;;
esac
case "$ref" in
  *[!v0-9.]*) echo "error: gogdl_flutter in $lock is not pinned by a vX.Y.Z tag: $ref" >&2; exit 1 ;;
esac

refs=$(git ls-remote "$remote" "refs/tags/$ref" "refs/tags/$ref^{}")
remote_sha=$(printf '%s\n' "$refs" | awk -v p="refs/tags/$ref^{}" '$2 == p { print $1; exit }')
if [ -z "$remote_sha" ]; then
  remote_sha=$(printf '%s\n' "$refs" | awk -v p="refs/tags/$ref" '$2 == p { print $1; exit }')
fi

if [ -z "$remote_sha" ]; then
  echo "error: gogdl_flutter $ref is not on $remote: update the mirror before pinning it here" >&2
  exit 1
fi
if [ "$remote_sha" != "$sha" ]; then
  echo "error: gogdl_flutter $ref is $remote_sha on $remote, but $lock pins $sha" >&2
  exit 1
fi
echo "check_bridge_pin: gogdl_flutter $ref is $sha on $remote"
