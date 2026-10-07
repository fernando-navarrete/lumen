# GAPS

Known gaps, bugs and improvement opportunities in Lumen. Tick an item off (`[x]`) when it's fixed, and
add new findings under the matching section. `fvm flutter analyze` is clean as of this audit
(2026-09-22), so everything below is behavioral or structural, not lint.

Priority tags: **P0** = broken behavior users will hit · **P1** = important gap · **P2** = polish / cleanup.

---

## 1. Bugs

- [x] **P0 — Saves tab progress never updates while syncing.** Fixed in `v1.0.4` with a stopgap
  (watch the whole `savesStateProvider`); the proper fix landed in `v1.1.0` (item 4.1 — immutable
  task objects), and `saves_tab.dart` went back to a `select`.
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

- [x] **P1 — Uninstall.** There's no way to remove a game: delete its files, optionally delete its
  prefix, and reset its `GameConfig`. Fixed in `v1.3.0`: `Uninstaller.uninstallGame` refuses while
  the game runs, stops any job, deletes the install folder (only if Lumen created it, or the user
  confirms) and optionally the Lumen-owned prefix and logs through `deleteDirectoryGuarded`, then
  removes the game's whole `GameConfig` entry. A failed delete leaves the game installed.
- [x] **P1 — Cancel / pause downloads, verifications and repairs.** Nothing can be stopped once started.
  A comment in `games_state.dart:341` mentions a "Pause" that doesn't exist. Fixed in `v1.3.0`:
  every job takes an app-owned `JobCancel` that `GogdlBackend` forwards to the bridge's
  `CancelToken`. Verification and repair end `TaskStatus.cancelled`; downloads can be paused
  (`GameStatus.paused`, files kept) or cancelled with or without deleting their files.
- [x] **P1 — Resume downloads interrupted by an app exit.** A game left in `downloading` is coerced to
  `notInstalled` on load, and its partial files are orphaned. Fixed in `v1.3.0`: with a
  `pendingInstallPath` it loads as `paused` ("Paused — interrupted", no auto-resume), and Resume
  always runs `repairDownload`.
- [x] **P1 — Stop a running game.** `LaunchNotifier` keeps no handle to kill the process tree (and
  Proton/wineserver). Fixed in `v1.2.0`: `LaunchNotifier.stopGame` runs the release's
  `files/bin/wineserver -k` with `WINEPREFIX=<prefix>/pfx` (the game's Windows processes are
  reparented to init, so no signal to the spawned process can reach them). If the spawned process
  (e.g. a wrapper) is still alive after a grace period, it gets SIGTERM, then SIGKILL, on its pid only,
  never its process group, which is Lumen's own. A new `LaunchStatus.stopping` shows a disabled
  "Stopping…", and a user-stopped game always ends `exited`, whatever its exit code. The `Process`
  handle lives in a private per-game `_LiveLaunch`, not in the immutable `RunningGame`.
- [ ] **P1 — Sign out in release builds.** `clearAuth` is only reachable from the debug-only Settings
  card.
- [ ] **P1 — Install or remove DLC on an already installed game.** Toggling products on the DLC tab only
  changes the stored set; nothing downloads until a manual repair.
- [ ] **P1 — Update detection.** Nothing flags that a newer build exists than the installed one.
- [x] **P1 — Downloads page actions.** Add dismiss/clear for failed and completed tasks, and a Retry
  button for failed downloads and repairs (only failed verifications get "Repair" today). Surface the
  actual error text for downloads and repairs. Fixed in `v1.3.0`: dismiss (×) and "Clear finished"
  (sparing running and paused tasks), Retry via `retryDownload`/`startRepair`, and `jobErrorText`
  maps `GogError.kind()` to Lumen's own wording.
- [x] **P1 — Proton version removal UI.** `removeVersion` exists but nothing calls it. It should also
  optionally delete the files, since the default install dir is Lumen-owned (the doc comment claims
  "the user picked that location", which is no longer true). Fixed in `v1.3.0`: a remove action per
  installed row with a confirm dialog and an "Also delete its files" checkbox.
- [x] **P2 — Per-game logs.** Game stdout/stderr is piped into Lumen's own stdout
  (`launch_state.dart:136`). Write it to `<lumenDataDir>/logs/<gameId>.log` and link it from the UI.
  Fixed in `v1.2.0`: each launch rotates `<gameId>.log` to `<gameId>.previous.log`, then writes a
  header (command, cwd, env vars, executable source), wineboot's output, the game's stdout/stderr
  (only there, in all builds) and a footer with the exit code and duration. The log is closed before
  the exit state is committed. A log that can't be opened never blocks the launch. "Open log" is in
  the Settings tab's "Game log" card and on the launch-failure snackbar.
- [ ] **P2 — Cap game log size.** Since `v1.2.0` each launch truncates `<gameId>.log` and keeps one
  `<gameId>.previous.log`, but a single chatty session (e.g. `PROTON_LOG`-level output or a game
  spamming stderr) can still grow its log without bound. Cap it per launch (stop writing, or keep
  the head and tail) if that turns up in practice.
- [ ] **P2 — Prefix tools.** Add "open prefix folder", "reset prefix", winecfg and winetricks, plus an
  "open install folder" action.
- [x] **P2 — Disk space check** before installing, using the download size. Fixed in `v1.3.0`:
  Install shows the download and on-disk sizes against the folder's free space, blocks only when
  the install can't fit, and never blocks on a failed lookup. Import, Resume and Retry skip it.
- [ ] **P2 — Cancel a Proton-GE download.** Out of scope for `v1.3.0`. gogdl-lib `v1.2.0` now cleans
  up a failed or dropped extraction and the bridge takes a `CancelToken`, so only Lumen's
  `ProtonNotifier` (which ignores `Cancelled`) and a UI action are missing.
- [ ] **P2 — Cancel a save sync.** Same as above for `SavesNotifier`, which maps `Cancelled` to
  `failed` today.
- [ ] **P2 — Big-game resume timing and free-space wording.** Resume's verification pass was only
  timed on a small game (a resume journal in gogdl-lib may be needed for big ones), and the
  free-space dialog can't name the mount because the bridge returns bytes only.
- [ ] **P2 — Library refresh, sorting and metadata caching.** Since `v1.0.6`, `GogState` caches the
  owned-games list for the session (`gog_state.dart`'s `_ownedGamesCache`), so it's no longer
  refetched on every Library visit — only titles still are (see 5.1). There is still no manual
  refresh (to pick up newly purchased/redeemed games without restarting) and no offline view.
- [ ] **P2 — Desktop notifications** when a download, repair or sync finishes.
- [ ] **P2 — Playtime and last-played tracking** (the hero banner already says "CONTINUE PLAYING").
- [ ] **P2 — `.desktop` shortcuts / launch by game id** from outside the app.

## 3. Launching / Proton

- [x] **P1 — Resolve the executable from GOG metadata instead of heuristics.** GOG installs ship
  `goggame-<id>.info` with `playTasks` (the primary exe, its args and its working dir).
  `executable_finder.dart` guesses with substring skip-lists that also drop legitimate executables
  (`report`, `crash`, `install`, `support`, …). Fixed in `v1.2.0`: `LaunchResolver` tries the user's
  override, then the play task from exactly `goggame-<gameId>.info` (a `category: game` primary, else
  the first `game` task, else the primary launcher), and only then the scan. Only a picker choice is
  persisted. Auto results are re-resolved on every launch, so a game update that changes its exe is
  followed. The scan's skip-lists are unchanged, since it's now only the fallback.
- [x] **P1 — Move the executable scan off the UI isolate.** `findExecutables` does a synchronous
  recursive `listSync` over the whole install. Large games freeze the UI; use `Isolate.run` or async
  listing. Fixed in `v1.2.0`: `findExecutablesAsync` runs the scan in `Isolate.run`, and both Play
  and the Settings tab's "Change" use it behind a busy state (Play ignores repeat taps meanwhile).
- [x] **P1 — Launch args and wrapper are split on whitespace** (`game_settings_tab.dart:93,103`), so
  quoted arguments or paths with spaces can't be expressed. Use shell-style tokenizing. Fixed in
  `v1.2.0`: `lib/common/shell_words.dart`'s `splitShellWords`/`joinShellWords` (POSIX-ish quoting and
  escapes, no expansion) round-trip the fields. An unterminated quote shows as the field's error and
  keeps the last valid value saved. The command preview uses the same quoting.
- [x] **P1 — A stale executable breaks launch.** If the stored `executable` no longer exists (after an
  update or a moved install), launch fails instead of re-scanning or prompting. Fixed in `v1.2.0`:
  a missing override is cleared and the game falls back to auto (play task, then scan), telling the
  user `"<old>" is no longer in the install folder — using <new> instead` (or showing the notice in
  the picker). A missing install folder stops with its own message. The Settings tab marks a missing
  override before Play is pressed.
- [x] **P2 — Check `wineboot`'s exit code** (`launch_state.dart:110`). Fixed in `v1.2.1`: a non-zero
  `wineboot` exit fails the launch (`"Prefix initialization failed (exit N) — see the log"`) without
  spawning the game, and removes the just-created `<prefix>/pfx` so the next launch retries init
  instead of running in a half-created prefix.
- [x] **P2 — Validate before spawning.** Check that `$protonPath/proton` exists and that the wrapper's
  first token is on `PATH`, so failures give a clear message instead of a raw `ProcessException`.
  Fixed in `v1.2.2`: `executable_lookup.dart`'s `isExecutableFile`/`resolveExecutable` validate the
  proton script and, if set, the wrapper's first token (a path checked directly, a bare name walked
  on `PATH`) before wineboot runs, before `pfx` is created, and before the log rotates.
- [x] **P2 — Stop treating every non-zero exit code as a failure** (`launch_state.dart:144`). Many games
  exit non-zero normally, so this shows a spurious error snackbar. Note (`v1.1.0` Phase 6): this
  snackbar (`game_action_buttons.dart:111`) was dead code before `v1.1.0` — `previous` and `next`
  shared the same mutated `RunningGame`, so its `previous.status != failed` check was never true.
  Making `RunningGame` immutable fixed that, so the snackbar now actually fires, including for this
  gap's spurious case. Note (`v1.2.0`): a game the user stopped is already exempt, and always ends
  `exited` whatever its exit code. Fixed in `v1.2.3`: a spawned game now always ends `exited` with
  its exit code kept, except a non-zero exit within `immediateExitWindow` (10s) of the process being
  spawned, which is `failed` with `"The game exited immediately (code N)"`. The snackbar is no
  longer spurious — it fires only for a real crash-on-start, a Lumen-side failure, or a spawn error.
- [x] **P2 — Remove the `[DIAG]` `debugPrint`s** in `launch_state.dart`. Fixed in `v1.2.4`: all 8
  removed; the one piece of info they carried that wasn't already in the per-game log (the spawned
  pid) is now written to the log itself, right under `--- game ---`.
- [x] **P2 — Validate installed Proton versions against disk on load.** Fixed in `v1.2.5`: `_load`
  checks each entry's `proton` script with `isExecutableFile` (P2's check); a missing one is hidden
  from `ProtonState.installed`/`defaultVersion` for the session but kept in a private `_unavailable`
  map (and `_unavailableDefault`) so a later `_persist` doesn't drop it from prefs — a release on an
  unmounted custom `targetDir` reappears on its own once the drive is back, and Play already reports
  "no Proton-GE version installed" for a hidden default.

## 4. State management / architecture

- [x] **P1 — Make task objects immutable (4.1).** Fixed in `v1.1.0`: `ActivityTask`, `SaveTask`,
  `ProtonTask` and `RunningGame` all got `copyWith` (an `_unset` sentinel for nullable fields), and
  each owning notifier replaces the map entry on every event instead of mutating in place. Doing
  this surfaced a latent bug — a stream whose task had been dequeued/replaced could still clobber
  the task that replaced it — fixed with a stale-stream guard in each notifier's `_commit`. It also
  turned up dead code: the launch-failure snackbar in `game_action_buttons.dart` compared
  `previous`/`next` off what used to be the same mutated `RunningGame` instance, so its guard was
  never true; it now fires correctly.
- [x] **P1 — Add a `gogBackendProvider`.** Fixed in `v1.1.0`: `gogBackendProvider` constructs the
  `GogdlBackend(GogdlApi())` and owns its dispose; `gogStateProvider` watches it. Tests override it
  with `FakeGogBackend` via `test/helpers/container.dart`'s `createContainer()`.
- [x] **P1 — Fix the CLAUDE.md and code mismatch about models.** Fixed in `v1.1.0`: added
  `lib/models/{game_build,downloadable_product,proton_release}.dart` as plain immutable app-owned
  classes, and `GogdlBackend` adapts the bridge's own types into them.
- [x] **P1 — Nav state is mutable and duplicated.** Fixed in `v1.1.0`: `navBarItemProvider` is now a
  `NavBarNotifier extends Notifier<NavBarItem>` (`lib/state/home_state.dart`), the single source of
  truth; `NavBar` and `HomeScreen` both watch it instead of keeping their own copy.
- [x] **P2 — Simplify or remove `GogState`'s per-game stream caches.** Fixed in `v1.1.1`: removed the
  six stream caches (verification, repair, download, Proton download, save download, save upload)
  along with their `clear*Stream()` methods. Every owner already cleared the cache before starting
  (except the Import bug in section 1) and entries were never evicted, so the cache never
  deduplicated anything — it only risked handing a caller a stale, already-consumed stream. The
  job-starting `GogState` methods are now plain synchronous calls that start a fresh backend job and
  return a fresh stream every time; double-start protection already lived in the owning notifiers
  (a synchronous `running`-task check before the task is registered), so removing the cache changed
  no observable behavior.
- [x] **P2 — Make error handling consistent in `GogState`.** Fixed in `v1.1.2`: `getLoginUrl` and
  `getProtonReleases` now `catch (e)` like every other `GogState` method, and
  `GogdlBackend.getProtonReleases` no longer swallows the error into `[]` — it propagates, so
  `GogState.getProtonReleases` can return `null` on failure vs. `[]` for a genuinely empty page. The
  Proton releases dialog (`proton_manager.dart`) now shows a distinct "Couldn't load releases" + Retry
  state instead of an endless "Load more". Also fixed the related `DownloadsNotifier` gap from the same
  ROADMAP entry: a stream error arriving after a `finished`/`Finished` event no longer gets silently
  re-derived back to `completed` by `onDone` — `onDone` now no-ops once `onError` has already failed
  the task.
- [ ] **P2 — Keep library, details and Proton release data in providers.** It currently lives in widget
  `State` with `addPostFrameCallback` fetches. Owned games, names, builds, products, summaries and
  releases would work better as `FutureProvider.family`s: they'd survive tab switches, get loading and
  error states for free, and could be invalidated for refresh.
- [x] **P2 — Throttle `ProtonNotifier` and `SavesNotifier` emits** the way `DownloadsNotifier` does.
  Fixed in `v1.1.3`: the throttling/trailing-flush logic moved out of `DownloadsNotifier` into a
  shared `ThrottledTaskBuffer` (`lib/state/emit_throttle.dart`), which all three notifiers now use.
  `ProtonNotifier` throttles `Started`/`Progress` download events; `SavesNotifier` throttles every
  event that leaves a task `running` (`Progress`, `FileStarted`, `FileFinished`). Terminal
  status-transition commits (`onDone`, `onError`, and each notifier's own "finished" event) still
  flush immediately.
- [x] **P2 — Game settings persist the whole games JSON on every keystroke** (`onChanged` →
  `_persist`). Fixed in `v1.1.4`: `GamesNotifier.setLaunchArgs`/`setEnvVars`/`setLaunchWrapper` (the
  three keystroke-driven setters) now debounce the prefs write by 500ms instead of writing on every
  call; in-memory state still updates immediately. `GamesNotifier.flushPendingPersist` commits a
  pending write early — called from `GameSettingsTab`'s `dispose`/game-switch and from the
  notifier's own `ref.onDispose`, so leaving the tab or the app never drops the last edit.
- [x] **P2 — Add a schema version** to the persisted `games` JSON so future migrations aren't ad hoc
  type sniffing (see the productId string/int fallback). Fixed in `v1.1.5`: saves are now wrapped in
  `{"version": GamesNotifier.gamesSchemaVersion, "games": {...}}`; `GamesNotifier._load` upgrades
  anything older through a `_migrations` step list (the productId string/int fallback became the
  v0→v1 step) before decoding, and a stored version newer than the app is decoded best-effort
  instead of rejected. A bare pre-`v1.1.5` `games` map with no envelope is treated as version 0.
- [x] **P2 — Reuse a single `FlutterSecureStorage` instance.** Also handle the Linux case where no
  Secret Service or keyring is available (common on minimal WMs) with a clear message. Fixed in
  `v1.1.6`: `GogState` now takes a `FlutterSecureStorage` via the new `secureStorageProvider`
  instead of constructing one per call, and every storage call maps
  `flutter_secure_storage_linux`'s `Libsecret error`/`KeyringLocked` `PlatformException`s to a new
  `KeyringUnavailableError` with actionable text, surfaced through the existing `gogErrorText`
  snackbars.
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
  (`devlog/v1.1.0-foundation.md`): `login_screen.dart`'s outer `Container` uses
  `EdgeInsets.all(size.width * 0.1)`, so a wide-but-short window applies a width-derived margin to
  the *vertical* sides too, and `SignInPanel`'s "Open GOG login" `PrimaryButton.icon` overflows its
  row at any window size once the Onest font isn't loaded (its fallback glyph metrics are wider) —
  reproduced at both 1600×1000 and 1920×4200 test surfaces, so it isn't just a small-window issue.
  This is also why `LoginScreen` has no widget test in `test/screens/`; see Phase 8 in
  `devlog/v1.1.0-foundation.md`.
- [ ] **P2 — Set a window minimum size and a proper title** ("Lumen", not "lumen") in
  `linux/runner/my_application.cc`, plus an app icon.
- [ ] **P2 — Unify the responsive side-column widths.** `OverviewTab`, `BuildsTab` and `ProductsTab`
  each use different `pow(...)` formulas (flagged in code comments); share one breakpoint helper.
- [ ] **P2 — Check whether the GOG summary contains HTML** that's being shown raw in `OverviewTab`.
- [ ] **P2 — Make the DLC tab usable.** It has no empty state when a game has no DLC. The label
  "Select all products to download" is unclear. Also add select-all and select-none actions.
- [ ] **P2 — Keyboard and accessibility.** `ClickableContainer` is a bare `GestureDetector`, so it has
  no focus, keyboard activation or semantics. Use `InkWell`/`FocusableActionDetector`.
- [ ] **P2 — The "Installed" library filter also matches `downloading` and `paused`**
  (`library_page.dart:61`). Consider a separate "Installing" state or chip.

## 7. Testing, tooling and docs

- [x] **P0 — No tests at all.** Fixed in `v1.1.0`: 102 tests under `test/`, built against a fake
  `GogBackend` (`test/helpers/fake_gog_backend.dart`) so none of them need the Rust bridge's native
  library. Covers `GamesNotifier` persistence/`copyWith`, the stream-owning notifiers' event→state
  mapping (including every section 1 regression), `guardBridgeStream` and `findExecutables`, plus
  widget tests for the Library/Builds error states and nav.
- [x] **P1 — No CI.** Fixed in `v1.1.0`: GitLab CI on a self-hosted runner (`thinkcentre.home`),
  `.gitlab-ci.yml` running `flutter analyze --fatal-infos` and `flutter test` on every branch.
  Confirmed to go red on a failing test.
- [x] **P1 — The build isn't reproducible outside your LAN.** Addressed in `v1.1.0` by documenting
  the setup (README "Building" note) rather than mirroring: `gogdl_flutter` stays LAN-only
  (`ssh://git@thinkcentre.home:2200`), and CI runs on the same LAN via the self-hosted runner.
  Reachability from outside the LAN is deliberately deferred, not fixed.
- [ ] **P1 — README is the Flutter template.** Document what Lumen is, the system requirements
  (libsecret/keyring, the Rust toolchain for the bridge?), fvm setup, and build/run steps.
- [ ] **P2 — Clean up `pubspec.yaml`.** It still has the template description ("A new Flutter
  project.") and boilerplate comments, and lists `cupertino_icons`, which is unused.
- [x] **P2 — Tighten lints.** Done in CI/CD Phase 2: `unawaited_futures`, `cancel_subscriptions`, `close_sinks`,
  `avoid_dynamic_calls`, `prefer_final_locals`, `directives_ordering` and `always_declare_return_types` are on and gate `lint`.
  Still open: the `print` in `lib/screens/login/login_screen.dart:36` should be `debugPrint`/`logGogError`.
- [ ] **P2 — Merge `formatBytes`/`formatBytesBigint`** (`format.dart`), which are duplicates.
- [ ] **P2 — Stale comment** at `gog_state.dart:204` about a `buildId` param that no longer exists.
- [ ] **P2 — Packaging.** No AppImage, Flatpak or `.deb`, and no release pipeline.
- [ ] **P1 — RUSTSEC-2026-0285 accepted.** `rustls` 0.23.43 in `gogdl_flutter`'s `Cargo.lock` (fixed in 0.23.45) is
  ignored in `osv-scanner.toml` until its `ignoreUntil` date. Needs a bridge release that bumps `rustls`, then drop the ignore.
- [ ] **P2 — Scan in the dependency repos.** Run the same `scan` in `gogdl_flutter` and `gogdl-lib`, so a vulnerable
  crate is caught before Lumen pins the release.
- [ ] **P2 — Release job.** A GitLab release from tag notes and a built Linux artifact on `v*` tags (no `CHANGELOG.md` yet).
- [ ] **P2 — MR coverage.** `flutter test --coverage` plus a Cobertura conversion.
- [ ] **P2 — CI image isn't digest-pinned.** `gogdl-flutter-ci` is built on the runner host and is in no registry.
- [ ] **P2 — No `lockFileMaintenance`.** Renovate moves transitive packages only through a direct bump, since
  maintenance would skip the 7-day wait. Revisit if the lockfile goes stale.
