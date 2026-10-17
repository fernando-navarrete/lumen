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
- A minor release gets a `devlog/vX.Y.0-<name>.md` with its decisions and pitfalls; its patches are
  appended to it.

## v1.6.0 — Extras

- Prefix tools: open folder, reset, winecfg and winetricks, open install folder (GAPS §2).
- Desktop notifications when a task finishes (§2).
- Playtime and last-played tracking (§2).
- `.desktop` shortcuts and launch by game id (§2).
