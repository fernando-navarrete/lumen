# GAPS

Known gaps, bugs and improvement opportunities in Lumen. Tick an item off (`[x]`) when it's fixed, and
add new findings under the matching section. `fvm flutter analyze` is clean as of this audit
(2026-09-22), so everything below is behavioral or structural, not lint.

Priority tags: **P0** = broken behavior users will hit · **P1** = important gap · **P2** = polish / cleanup.

---

## 1. Bugs

- [x] **P0 — Saves tab progress never updates while syncing.** Fixed in `v1.0.4`: the tab now
  watches the whole `savesStateProvider` instead of a `select`, matching the Downloads page. The
  proper fix is item 4.1 (immutable task objects).
- [x] **P0 — Switching build wipes the game's whole config.** Fixed in `v1.0.2`: `setSelectedBuild`
  now uses `copyWith`, and switching the build of an installed game confirms first, then starts a
  repair against the new build.
- [x] **P0 — Re-running Import after a failed Import silently does nothing.** Fixed in `v1.0.3`:
  `startVerification` now dequeues a failed/completed task and clears the cached verification stream
  before starting, the same logic `startDownload` already used.
- [x] **P1 — A download with allocation errors is marked installed.** Fixed in `v1.0.5`: the
  download `onDone` now also checks `errorFiles`, matching repair.
- [x] **P1 — Hero banners refetch and flicker on every rebuild.** Fixed in `v1.0.11`: background
  links are now cached per game like boxart, so rebuilds reuse the same Future instead of reloading.
- [x] **P1 — The library never leaves the loading spinner on error or when empty.** Fixed in
  `v1.0.6`: `_GameGrid` now distinguishes loading, a failed fetch (`null`) and an empty library
  (`[]`), showing a message with a Retry button for the latter two. This also relies on
  `gogdl_flutter` `v1.1.3` / `gogdl-lib` `v1.0.11`, which filter `getOwnedGames()` down to real
  games (DLC and other non-game products used to surface as raw decode errors downstream). Since
  that filtering isn't cached upstream and doesn't preserve order (one `gamesdb.gog.com` lookup per
  owned product, unordered), `GogState.getOwnedGames` now caches and sorts the result itself, and
  a per-product lookup failure can make the result `[]` even though the library isn't actually
  empty — hence Retry on the empty state too, not just the error state.
- [x] **P1 — Builds tab crashes when fetching builds fails.** Fixed in `v1.0.7`: a failed fetch
  now shows an error with Retry (and an empty list shows a message) instead of crashing.
- [x] **P1 — `setState` can run after dispose in several async `initState` flows.** Fixed in
  `v1.0.8`: the login, Overview, DLC and Library flows (and `GameActionButtons`) now check
  `mounted` after every `await` before calling `setState` or `ref`.
- [x] **P1 — Debug and release builds handle errors differently.** Fixed in `v1.0.10`: the
  `GogState` image, summary and screenshot getters now log and return `''`/`[]` in both builds
  instead of throwing in debug.
- [x] **P1 — The login flow doesn't catch non-`GogError` failures.** Fixed in `v1.0.9`: a missing
  stored token is no longer treated as an error, and any other failure (restore or sign-in, e.g. no
  keyring) now shows a snackbar instead of escaping silently.
- [x] **P1 — Removing a Proton version leaves dangling per-game overrides.** Fixed in `v1.0.12`:
  removing a version now clears the override on games pinned to it, so they fall back to the global
  default.
- [x] **P2 — Saves downloaded before first launch may skip prefix init.** Fixed in `v1.0.14`: didn't
  reproduce (a save sync on a never-launched game fails instead of creating `pfx`). Syncing now stops
  early with a "launch the game once" message and no longer creates a prefix dir.
- [x] **P2 — `TextEditingController` is never disposed.** Fixed in `v1.0.8`: the login screen now
  disposes it.
- [x] **P2 — Proton download `onDone` always marks the task complete.** Fixed in `v1.0.13`: a
  download that closes without a `Finished` event is now marked failed (and can be retried) instead
  of installed.

## 2. Missing features

- [ ] **P1 — Uninstall.** There's no way to remove a game: delete its files, optionally delete its
  prefix, and reset its `GameConfig`.
- [ ] **P1 — Cancel / pause downloads, verifications and repairs.** Nothing can be stopped once started.
  A comment in `games_state.dart:341` mentions a "Pause" that doesn't exist.
- [ ] **P1 — Resume downloads interrupted by an app exit.** A game left in `downloading` is coerced to
  `notInstalled` on load, and its partial files are orphaned.
- [ ] **P1 — Stop a running game.** `LaunchNotifier` keeps no handle to kill the process tree (and
  Proton/wineserver).
- [ ] **P1 — Sign out in release builds.** `clearAuth` is only reachable from the debug-only Settings
  card.
- [ ] **P1 — Install or remove DLC on an already installed game.** Toggling products on the DLC tab only
  changes the stored set; nothing downloads until a manual repair.
- [ ] **P1 — Update detection.** Nothing flags that a newer build exists than the installed one.
- [ ] **P1 — Downloads page actions.** Add dismiss/clear for failed and completed tasks, and a Retry
  button for failed downloads and repairs (only failed verifications get "Repair" today). Surface the
  actual error text for downloads and repairs (`ActivityTask` has no `error` field; `SaveTask` does).
- [ ] **P1 — Proton version removal UI.** `removeVersion` exists but nothing calls it. It should also
  optionally delete the files, since the default install dir is Lumen-owned (the doc comment claims
  "the user picked that location", which is no longer true).
- [ ] **P2 — Per-game logs.** Game stdout/stderr is piped into Lumen's own stdout
  (`launch_state.dart:136`). Write it to `<lumenDataDir>/logs/<gameId>.log` and link it from the UI.
- [ ] **P2 — Prefix tools.** Add "open prefix folder", "reset prefix", winecfg and winetricks, plus an
  "open install folder" action.
- [ ] **P2 — Disk space check** before installing, using the download size.
- [ ] **P2 — Library refresh, sorting and metadata caching.** Since `v1.0.6`, `GogState` caches the
  owned-games list for the session (`gog_state.dart`'s `_ownedGamesCache`), so it's no longer
  refetched on every Library visit — only titles still are (see 5.1). There is still no manual
  refresh (to pick up newly purchased/redeemed games without restarting) and no offline view.
- [ ] **P2 — Desktop notifications** when a download, repair or sync finishes.
- [ ] **P2 — Playtime and last-played tracking** (the hero banner already says "CONTINUE PLAYING").
- [ ] **P2 — `.desktop` shortcuts / launch by game id** from outside the app.

## 3. Launching / Proton

- [ ] **P1 — Resolve the executable from GOG metadata instead of heuristics.** GOG installs ship
  `goggame-<id>.info` with `playTasks` (the primary exe, its args and its working dir).
  `executable_finder.dart` guesses with substring skip-lists that also drop legitimate executables
  (`report`, `crash`, `install`, `support`, …).
- [ ] **P1 — Move the executable scan off the UI isolate.** `findExecutables` does a synchronous
  recursive `listSync` over the whole install. Large games freeze the UI; use `Isolate.run` or async
  listing.
- [ ] **P1 — Launch args and wrapper are split on whitespace** (`game_settings_tab.dart:93,103`), so
  quoted arguments or paths with spaces can't be expressed. Use shell-style tokenizing.
- [ ] **P1 — A stale executable breaks launch.** If the stored `executable` no longer exists (after an
  update or a moved install), launch fails instead of re-scanning or prompting.
- [ ] **P2 — Check `wineboot`'s exit code** (`launch_state.dart:110`).
- [ ] **P2 — Validate before spawning.** Check that `$protonPath/proton` exists and that the wrapper's
  first token is on `PATH`, so failures give a clear message instead of a raw `ProcessException`.
- [ ] **P2 — Stop treating every non-zero exit code as a failure** (`launch_state.dart:144`). Many games
  exit non-zero normally, so this shows a spurious error snackbar. Note (`v1.1.0` Phase 6): this
  snackbar (`game_action_buttons.dart:111`) was dead code before `v1.1.0` — `previous` and `next`
  shared the same mutated `RunningGame`, so its `previous.status != failed` check was never true.
  Making `RunningGame` immutable fixed that, so the snackbar now actually fires, including for this
  gap's spurious case.
- [ ] **P2 — Remove the `[DIAG]` `debugPrint`s** in `launch_state.dart`.
- [ ] **P2 — Validate installed Proton versions against disk on load.** A directory deleted outside the
  app still shows as installed.

## 4. State management / architecture

- [ ] **P1 — Make task objects immutable (4.1).** `ActivityTask`, `SaveTask`, `ProtonTask` and
  `RunningGame` have mutable fields and are mutated in place inside "immutable" state objects. This
  contradicts the CLAUDE.md convention and causes the Saves tab bug in section 1. Give them `copyWith`
  and replace the map entry on every event.
- [ ] **P1 — Add a `gogBackendProvider`.** `gogStateProvider` hardwires `GogdlBackend(GogdlApi())`
  (`gog_state.dart:400`); a separate provider would let tests override it with a fake `GogBackend`.
- [ ] **P1 — Fix the CLAUDE.md and code mismatch about models.** The docs say `GameBuild`,
  `DownloadableProduct` and `ProtonRelease` are app-owned classes under `lib/models/`. That directory
  doesn't exist; `GogBackend` returns the bridge's own types, so fakes and tests still depend on
  `gogdl_flutter`. Either add the models and adapt them in `GogdlBackend`, or correct the docs.
- [ ] **P1 — Nav state is mutable and duplicated.** `NavBarState` is a mutable object inside a plain
  `Provider`, driven by `setState` in `HomeScreen`. `NavBar` also keeps its own `_selectedItem`
  (`nav_bar.dart:24`), and the two can drift apart. Convert it to a `Notifier<NavBarItem>` with one
  source of truth.
- [ ] **P2 — Simplify or remove `GogState`'s per-game stream caches.** Every owner already clears the
  cache before starting (except the Import bug in section 1), and entries are never evicted. The cache
  mostly acts as a trap: callers can be handed a stale, already-consumed stream.
- [ ] **P2 — Make error handling consistent in `GogState`.** Some methods catch only `GogError`
  (`getLoginUrl`, `getProtonReleases`), others catch everything.
  `GogdlBackend.getProtonReleases` swallows errors and returns `[]`, so the UI shows "No releases
  loaded" with an endless "Load more" and can't tell a failure from the end of the list.
- [ ] **P2 — Keep library, details and Proton release data in providers.** It currently lives in widget
  `State` with `addPostFrameCallback` fetches. Owned games, names, builds, products, summaries and
  releases would work better as `FutureProvider.family`s: they'd survive tab switches, get loading and
  error states for free, and could be invalidated for refresh.
- [ ] **P2 — Throttle `ProtonNotifier` and `SavesNotifier` emits** the way `DownloadsNotifier` does.
  Right now every progress event triggers a rebuild.
- [ ] **P2 — Game settings persist the whole games JSON on every keystroke** (`onChanged` →
  `_persist`). Debounce it, or persist on blur/submit.
- [ ] **P2 — Add a schema version** to the persisted `games` JSON so future migrations aren't ad hoc
  type sniffing (see the productId string/int fallback).
- [ ] **P2 — Reuse a single `FlutterSecureStorage` instance.** Also handle the Linux case where no
  Secret Service or keyring is available (common on minimal WMs) with a clear message.
- [ ] **P2 — `LibraryPage` loses the selected game** when switching nav tabs and back.

## 5. Performance

- [ ] **P1 — Game titles are fetched serially (5.1)** (`library_page.dart:104`), one `await` per game,
  on every Library visit (the owned-games list itself is cached since `v1.0.6`, but not titles).
  Fetch them in parallel (bounded) and cache them in a provider.
- [ ] **P2 — Filter the grid without hiding untitled games.** Games whose title hasn't loaded or failed
  render as `SizedBox.shrink()` but still count toward "N games" and take a grid slot. Rarer since
  `v1.0.6` now that non-game products are filtered out server-side, but a slow/failed title fetch
  for an actual game still hits this.
- [ ] **P2 — Screenshots use `BoxFit.fill`** (`overview_tab.dart:81`), which distorts them; use `cover`.
  Consider `cacheWidth` for grid thumbnails.

## 6. UI / UX

- [ ] **P1 — Login screen polish.** Show a loading state while restoring auth (the login card currently
  flashes before navigating home). Replace the hardcoded 10 s auto-advance to step 3. Show an error
  message that matches the actual failure, not always "code looks incomplete". Replace the
  `MediaQuery` width/height arithmetic in `SignInPanel` with a layout that works at small window
  sizes. Found while writing Phase 8's widget-test harness
  (`v1.1.0-FOUNDATION_WORKPLAN.md`): `login_screen.dart`'s outer `Container` uses
  `EdgeInsets.all(size.width * 0.1)`, so a wide-but-short window applies a width-derived margin to
  the *vertical* sides too, and `SignInPanel`'s "Open GOG login" `PrimaryButton.icon` overflows its
  row at any window size once the Onest font isn't loaded (its fallback glyph metrics are wider) —
  reproduced at both 1600×1000 and 1920×4200 test surfaces, so it isn't just a small-window issue.
  This is also why `LoginScreen` has no widget test in `test/screens/`; see the workplan's Phase 8
  session-log entry.
- [ ] **P2 — Set a window minimum size and a proper title** ("Lumen", not "lumen") in
  `linux/runner/my_application.cc`, plus an app icon.
- [ ] **P2 — Unify the responsive side-column widths.** `OverviewTab`, `BuildsTab` and `ProductsTab`
  each use different `pow(...)` formulas (flagged in code comments); share one breakpoint helper.
- [ ] **P2 — Check whether the GOG summary contains HTML** that's being shown raw in `OverviewTab`.
- [ ] **P2 — Make the DLC tab usable.** It has no empty state when a game has no DLC. The label
  "Select all products to download" is unclear. Also add select-all and select-none actions.
- [ ] **P2 — Keyboard and accessibility.** `ClickableContainer` is a bare `GestureDetector`, so it has
  no focus, keyboard activation or semantics. Use `InkWell`/`FocusableActionDetector`.
- [ ] **P2 — The "Installed" library filter also matches `downloading`** (`library_page.dart:61`).
  Consider a separate "Installing" state or chip.

## 7. Testing, tooling and docs

- [ ] **P0 — No tests at all.** Add `test/` with a fake `GogBackend`, starting with `GamesNotifier`
  persistence round-trip and `copyWith` sentinel, the `DownloadsNotifier` event→state mapping
  (including the section 1 bugs), `SavesNotifier`, `guardBridgeStream` (late error after `onDone`) and
  `findExecutables`.
- [ ] **P1 — No CI.** Add at least `fvm flutter analyze` and `fvm flutter test`.
- [ ] **P1 — The build isn't reproducible outside your LAN.** `gogdl_flutter` is pulled over SSH from
  `thinkcentre.home:2200`, which blocks CI and other contributors. Mirror it to a reachable remote or
  document the setup.
- [ ] **P1 — README is the Flutter template.** Document what Lumen is, the system requirements
  (libsecret/keyring, the Rust toolchain for the bridge?), fvm setup, and build/run steps.
- [ ] **P2 — Clean up `pubspec.yaml`.** It still has the template description ("A new Flutter
  project.") and boilerplate comments, and lists `cupertino_icons`, which is unused.
- [ ] **P2 — Tighten lints.** Enable stricter rules on top of `flutter_lints` (e.g.
  `prefer_final_locals`, `unawaited_futures`, `always_declare_return_types`). Replace the stray
  `print` in `login_screen.dart:36` with `debugPrint`/`logGogError`.
- [ ] **P2 — Merge `formatBytes`/`formatBytesBigint`** (`format.dart`), which are duplicates.
- [ ] **P2 — Stale comment** at `gog_state.dart:204` about a `buildId` param that no longer exists.
- [ ] **P2 — Packaging.** No AppImage, Flatpak or `.deb`, and no release pipeline.
