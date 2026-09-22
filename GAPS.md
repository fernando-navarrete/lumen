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
- [ ] **P1 — A download with allocation errors is marked installed.** The download `onDone`
  (`downloads_state.dart:340`) only checks `stage == 'finished'`, not `errorFiles`. Repair does check it
  (`:443`). The Downloads page then shows a "completed with errors" row while the library says
  Installed.
- [ ] **P1 — Hero banners refetch and flicker on every rebuild.** `getGameBackgroundLink` isn't cached
  like boxart and names are, and `library_page.dart:133` / `game_header.dart:43` call it inside
  `build()`. Each rebuild (for example any `gamesStateProvider` change) hands `FutureBuilder` a new
  Future, which resets it to the loader and re-issues the bridge call.
- [ ] **P1 — The library never leaves the loading spinner on error or when empty.** `_GameGrid`
  (`library_page.dart:84,100`) treats `null` (the fetch failed) and `[]` (no games) the same way: an
  endless `CenteredLoader`. It needs error and empty states, plus a retry.
- [ ] **P1 — Builds tab crashes when fetching builds fails.** `_builds!.indexWhere`
  (`builds_tab.dart:48`) runs when `getBuilds` returns `null`.
- [ ] **P1 — `setState` can run after dispose in several async `initState` flows.** Affected:
  `login_screen.dart:130` (a 10 s `Future.delayed` with no `mounted` check), `builds_tab.dart:41,51`,
  `overview_tab.dart:34,36`, `products_tab.dart:52` and `library_page.dart:86,91`. Leaving the page
  mid-fetch throws.
- [ ] **P1 — Debug and release builds handle errors differently.** In `GogState`, `getGameBackgroundLink`,
  `getGameBoxartLink`, `getGameSummary` and `getGameScreenshots` (`gog_state.dart:51-104`) *throw* in
  debug but return `''`/`[]` in release. Debug builds hit unhandled async errors and endless loaders
  (for example the Overview summary) that release builds never show. Pick one contract; CLAUDE.md says
  "return null on failure".
- [ ] **P1 — The login flow doesn't catch non-`GogError` failures.** `restoreAuthFromStorage` throws a
  plain `Exception('No auth token…')` on every first run, and `login_screen.dart:45` only catches
  `GogError`. A secure-storage write failure in `_onSubmitCode` (for example no keyring) escapes the
  same way, leaving the user on the login screen with no error shown.
- [ ] **P1 — Removing a Proton version leaves dangling per-game overrides.** After
  `ProtonNotifier.removeVersion`, a game pinned to that tag fails at launch with "no longer installed".
  The Settings dropdown then shows a value that isn't among its entries.
- [ ] **P2 — Saves downloaded before first launch may skip prefix init (needs verification).**
  `SavesNotifier` passes `<prefix>/pfx` to the bridge, which can create `pfx/drive_c/...` in a prefix
  that was never initialized. `LaunchNotifier` (`launch_state.dart:104`) uses "`pfx` exists" as its
  "already initialized" check, so it would then skip `wineboot`. Test this against a fresh game, and
  check Proton's `version` file instead of the folder.
- [ ] **P2 — `TextEditingController` is never disposed** (`login_screen.dart:27`).
- [ ] **P2 — Proton download `onDone` always marks the task complete** (`proton_state.dart:165`), even
  when no `Finished` event arrived. In that case it falls back to a guessed `'$dir/$tag'` path.

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
- [ ] **P2 — Library refresh, sorting and metadata caching.** The owned-games list and titles are
  refetched every time the Library tab is shown (see 5.1). There is no manual refresh and no offline
  view.
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
  exit non-zero normally, so this shows a spurious error snackbar.
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

- [ ] **P1 — Game titles are fetched serially (5.1)** (`library_page.dart:87`), one `await` per game,
  on every Library visit. Fetch them in parallel (bounded) and cache them in a provider.
- [ ] **P2 — Filter the grid without hiding untitled games.** Games whose title hasn't loaded or failed
  render as `SizedBox.shrink()` but still count toward "N games" and take a grid slot.
- [ ] **P2 — Screenshots use `BoxFit.fill`** (`overview_tab.dart:81`), which distorts them; use `cover`.
  Consider `cacheWidth` for grid thumbnails.

## 6. UI / UX

- [ ] **P1 — Login screen polish.** Show a loading state while restoring auth (the login card currently
  flashes before navigating home). Replace the hardcoded 10 s auto-advance to step 3. Show an error
  message that matches the actual failure, not always "code looks incomplete". Replace the
  `MediaQuery` width/height arithmetic in `SignInPanel` with a layout that works at small window
  sizes.
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
