# ROADMAP

The order in which the items in [GAPS.md](GAPS.md) will be fixed, and the version tag each one ships
under.

## Versioning rules

- Everything stays on **1.x.x**.
- **Patch** (`1.0.x`): one tag per small, self-contained bugfix.
- **Minor** (`1.x.0`): a big update, meaning a feature set or cross-cutting refactor. Patches then
  continue from `.1` under that minor.
- Tags use the existing `vX.Y.Z` format. `v1.0.0`–`v1.0.2` already exist, so the next tag is
  **`v1.0.3`**.
- For each release: bump `version:` in `pubspec.yaml` to match, tick the item(s) in `GAPS.md`,
  commit, then tag.

The bugfixes come first. Each is small and doesn't depend on the larger refactors. Where a quick
patch sits in front of a proper fix that lands later, the entry says so.

---

## 1.0.x — Bugfixes

Fixes are ordered by user impact: data loss first, then broken flows, crashes, and finally cosmetic
or edge-case issues.

| Tag | Fix | GAPS ref |
|---|---|---|
| `v1.0.2` ✅ | Switching build no longer wipes the game's config (`setSelectedBuild` → `copyWith`; decide on the re-download/repair flow for installed games). | §1 P0 |
| `v1.0.3` ✅ | Re-running Import after a failed/completed Import works (dequeue the old task and clear the cached verification stream). | §1 P0 |
| `v1.0.4` ✅ | Saves tab progress updates live. *Quick fix:* watch the whole `savesStateProvider`. The proper fix is immutable tasks in `v1.1.0`. | §1 P0 |
| `v1.0.5` ✅ | Downloads with allocation errors are no longer marked installed. | §1 P1 |
| `v1.0.6` ✅ | Library shows error and empty states with a Retry, instead of spinning forever. | §1 P1 |
| `v1.0.7` ✅ | Builds tab no longer crashes when fetching builds fails. | §1 P1 |
| `v1.0.8` ✅ | No `setState` after dispose in async `initState` flows. Also dispose the login `TextEditingController`. | §1 P1, P2 |
| `v1.0.9` ✅ | Login catches non-`GogError` failures (no stored token, keyring write errors) and shows an error. | §1 P1 |
| `v1.0.10` ✅ | Debug and release builds follow the same error contract in `GogState` metadata getters (return empty/null in both). | §1 P1 |
| `v1.0.11` ✅ | Hero banners stop refetching and flickering (cache `getGameBackgroundLink` like boxart). | §1 P1 |
| `v1.0.12` ✅ | Removing a Proton version clears per-game overrides that point to it. | §1 P1 |
| `v1.0.13` ✅ | A Proton download that closes without a `Finished` event is marked failed, not installed. | §1 P2 |
| `v1.0.14` ✅ | Save syncing before the first launch fails with a clear message (the skipped-prefix-init bug didn't reproduce). | §1 P2 |

## v1.1.0 — Foundation: tests, CI and state architecture

This goes before any feature work so that everything after it lands with tests.

- Add `gogBackendProvider` so tests can swap in a fake `GogBackend` (§4).
- Make `ActivityTask`, `SaveTask`, `ProtonTask` and `RunningGame` immutable, replacing the `v1.0.4`
  stopgap (§4.1).
- Convert nav state to a single `Notifier<NavBarItem>` (§4).
- Resolve the `lib/models/` mismatch between CLAUDE.md and the code (§4).
- Add `test/` covering the notifiers, `guardBridgeStream` and `findExecutables`, including
  regression tests for the 1.0.x fixes (§7 P0).
- Add CI (GitLab CI, self-hosted runner on `thinkcentre.home`) running analyze and test, reachable
  from CI on the LAN; reachability from outside the LAN is deferred (§7 P1).

Follow-up patches (`v1.1.1+`), one per tag:
1. `v1.1.1`: simplify or remove `GogState` stream caches (§4).
2. `v1.1.2`: make error handling consistent in `GogState` / `getProtonReleases` (§4). Also:
   in `DownloadsNotifier`, `stream.listen`'s `onError` sets a task `failed`, but
   `cancelOnError` is false, so a `finished` event followed by a late stream error still lets
   `onDone` run afterward and re-derive `completed`/installed from `stage`/`errorFiles` —
   the error is effectively swallowed. Characterized (not fixed) in
   `test/state/downloads_state_test.dart`'s "known gap" test (Phase 4a,
   `v1.1.0-FOUNDATION_WORKPLAN.md`).
3. `v1.1.3`: throttle `ProtonNotifier` and `SavesNotifier` emits (§4).
4. `v1.1.4`: debounce game-settings persistence (§4).
5. `v1.1.5`: add a schema version to the persisted `games` JSON (§4).
6. `v1.1.6`: reuse one `FlutterSecureStorage` instance and add a clear no-keyring message (§4).

## v1.2.0 — Launching and Proton

- Resolve executables from `goggame-<id>.info` `playTasks`, keeping the scan as a fallback (§3).
- Move the executable scan off the UI isolate (§3).
- Shell-style tokenizing for launch args and the wrapper (§3).
- Re-scan or prompt when the stored executable is missing (§3).
- Stop a running game (§2).
- Per-game log files (§2).

Follow-up patches (`v1.2.1+`), one per tag:
1. `v1.2.1`: check `wineboot`'s exit code (§3).
2. `v1.2.2`: validate the Proton binary and wrapper before spawning (§3).
3. `v1.2.3`: stop treating every non-zero exit as a failure (§3).
4. `v1.2.4`: remove the `[DIAG]` prints (§3).
5. `v1.2.5`: validate installed Proton versions against disk on load (§3).

## v1.3.0 — Download management

- Cancel and pause for downloads, verifications and repairs (§2).
- Resume downloads interrupted by an app exit (§2).
- Downloads page: dismiss/clear, Retry for failed downloads and repairs, and real error text (§2).
- Uninstall: files, optionally the prefix, and the config reset (§2).
- Disk space check before install (§2).
- Proton version removal UI, with optional file deletion (§2).

## v1.4.0 — Library and account

- Move library, details and Proton release data into `FutureProvider.family`s (§4).
- Fetch titles in parallel and cache them, and add a library refresh (§2, §5.1).
- Keep the selected game across nav tab switches (§4).
- Update detection for installed builds (§2).
- Install or remove DLC on installed games, plus DLC tab empty state and select-all (§2, §6).
- Sign out in release builds (§2).

Follow-up patches (`v1.4.1+`), one per tag:
1. `v1.4.1`: stop untitled games taking grid slots and counting toward "N games" (§5).
2. `v1.4.2`: use `BoxFit.cover` and `cacheWidth` for screenshots (§5).
3. `v1.4.3`: add a separate "Installing" state in library filters (§6).

## v1.5.0 — UI polish and packaging

- Login screen: loading state on auth restore, no hardcoded 10 s advance, accurate errors, layout
  that works at small window sizes (§6).
- Window title "Lumen", a minimum size, and an app icon (§6).
- Shared responsive breakpoint helper for the detail tabs (§6).
- Keyboard focus and semantics for `ClickableContainer` (§6).
- Rewrite the README, clean up `pubspec.yaml`, and tighten lints (§7).
- AppImage and/or Flatpak packaging and a release pipeline (§7).

Follow-up patches (`v1.5.1+`), one per tag:
1. `v1.5.1`: check whether the GOG summary is HTML and render it correctly (§6).
2. `v1.5.2`: `formatBytesBigint` has had no callers since `v1.1.0` Phase 2 (`ProtonRelease.downloadSize`
   is a plain `int` now), so this is just deleting it, not merging. Also fix the stale `buildId`
   comment (§7).

## v1.6.0 — Extras

- Prefix tools: open folder, reset, winecfg and winetricks, open install folder (§2).
- Desktop notifications when a task finishes (§2).
- Playtime and last-played tracking (§2).
- `.desktop` shortcuts and launch by game id (§2).
