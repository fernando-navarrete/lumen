# ROADMAP

What ships next, and under which tag. The open items themselves are described in [GAPS.md](GAPS.md);
what already shipped is in [CHANGELOG.md](CHANGELOG.md) and `devlog/` (one file per minor release).

## Versioning rules

- Everything stays on **1.x.x**, in the `vX.Y.Z` tag format.
- **Minor** (`1.x.0`): a feature set or a cross-cutting refactor. **Patch** (`1.x.y`): one small,
  self-contained fix per tag, continuing from `.1` under the current minor.
- For each release: bump `version:` in `pubspec.yaml`, add the `## X.Y.Z` section to `CHANGELOG.md`
  (the tag pipeline refuses a tag without both), remove the shipped items from `GAPS.md`, merge, then
  tag the merge commit on `main`.
- After pushing the tag, check that its pipeline is green, the GitLab release has three files (the
  AppImage, `.sha256` and `.zsync`), and the GitHub release is published with the same three files
  and marked "Latest" (unless it is a hotfix on an older minor, which must not be).
- A minor release gets a `devlog/vX.Y.0-<name>.md` with its decisions and pitfalls; its patches are
  appended to it.

## v1.6.0 — Distribution ✅

- GitHub releases from the tag pipeline: a `github-release` job after `release`.
- AppImage auto-update through zsync update information on the GitHub releases.
- Docs: the `.gitlab-ci.yml` header, CLAUDE.md's release section, the new secret in SECURITY.md's
  "Rotate secrets" list, and the release steps under "Versioning rules".
- README "Installing": download from the GitHub release, and updating in place.
- SECURITY.md and README: the GitHub mirror also carries the releases.

## v1.7.0 — Extras

- Prefix tools: open folder, reset, winecfg and winetricks, open install folder (GAPS §2).
- Desktop notifications when a task finishes (§2).
- Playtime and last-played tracking (§2).
- `.desktop` shortcuts and launch by game id (§2).

## Later

- Launch through umu-launcher as an opt-in runner, after a hands-on spike settles the prefix layout,
  stopping a game inside the runtime container and the exit behaviour (GAPS §2).
- An AUR package (`lumen-gog-bin`), updated by an `aur` job after `github-release`. Blocked until AUR
  account registration reopens (GAPS §4).
