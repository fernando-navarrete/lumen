# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Lumen is a Flutter desktop app (Linux only — see `linux/`, no other platform folders) that acts as a
GOG game library manager, downloader, and Proton launcher.

All GOG API access, downloading, verification/repair, save-cloud sync, and Proton-GE release fetching
are delegated to a Rust bridge consumed as the `gogdl_flutter` package (via `flutter_rust_bridge`),
pinned in `pubspec.yaml`. `lib/state/gog_backend.dart` declares a `GogBackend` interface abstracting
that bridge away from any particular implementation, and `lib/state/gog_state.dart`'s `GogState` — the
facade nearly everything else talks to — wraps a `GogBackend`. `lib/state/gogdl_backend.dart`'s
`GogdlBackend` is the implementation wired up in `gogBackendProvider` (`gog_state.dart`), which
`gogStateProvider` watches, adapting each `GogBackend` method to a `GogdlApi` call.

Bridge data types (`GameBuild`, `DownloadableProduct`, `ProtonRelease`) are app-owned plain-Dart
classes under `lib/models/`, not bridge-generated ones — a new backend adapts its own types into
these, not the other way around. `ProtonDownloadProgress`, `VerifyDownloadProgress`,
`DownloadGameProgress`, `RepairGameProgress`, `DownloadSavesProgress` and `UploadSavesProgress` are
the exceptions: all six stay the bridge's own freezed unions, and their owning notifiers
(`ProtonNotifier` in `lib/state/proton_state.dart`, `DownloadsNotifier` in
`lib/state/downloads_state.dart`, which owns `DownloadGameProgress` for downloads,
`VerifyDownloadProgress` for verification, and `RepairGameProgress` for repair, and `SavesNotifier`
in `lib/state/saves_state.dart` for both save-sync unions) adapt them directly rather than going
through an app-owned model.

## Commands

This project uses **fvm** (Flutter Version Management) — always prefix Flutter/Dart commands with
`fvm`, not the bare `flutter`/`dart` binaries, so the pinned SDK version from `.fvm/fvm_config.json`
is used (CI reads the same pin from `.fvmrc`).

```bash
fvm flutter pub get                        # install dependencies
fvm flutter analyze                        # static analysis / lints (flutter_lints)
fvm flutter run -d linux                    # run the app (only Linux target exists)
fvm flutter build linux                     # build the Linux release binary
fvm flutter test                            # run the test suite (no native library needed)
```

Tests live under `test/`, built against the `GogBackend` interface. `test/helpers/fake_gog_backend.dart`'s
`FakeGogBackend` and `test/helpers/container.dart`'s `createContainer()` override `gogBackendProvider`
(and `sharedPreferencesProvider`) with a fake, so a test never needs the Rust bridge's native library
loaded. Tests must never construct `GogdlBackend`/`GogdlApi()` directly or call `RustLib.init()` —
either would require that native library, which isn't available in CI. Anything that touches
`lib/common/app_paths.dart` (Proton prefixes, the Proton install dir, the fake Steam compat client
dir) must never read or write under the real `lumenDataDir()`; `test/helpers/temp_data_home.dart`'s
`useTempDataHome()` points it at a temp dir for the test via `app_paths.dart`'s
`xdgDataHomeOverride` test seam. `test/flutter_test_config.dart` runs before every test file and
disables `google_fonts`' runtime HTTP fetch, so widget tests don't hit the network for the Onest
font (it silently falls back to the default font instead). Widget tests (`test/screens/`) use
`test/helpers/pump_app.dart`'s `pumpApp()`, which wraps a widget in a real `MaterialApp`/`Scaffold`
backed by a `createContainer()`-style `ProviderContainer` and sizes the test surface to a desktop
window; it doesn't call `pumpAndSettle()` itself because several screens show an indefinitely
spinning `CenteredLoader` while their first fetch is pending.

CI (GitLab CI, self-hosted runner on `thinkcentre.home`, `.gitlab-ci.yml`) runs
`flutter analyze --fatal-infos` and `flutter test` on every tag push (branch pushes don't
trigger a pipeline).

## Architecture

### State management (Riverpod)

All app state lives in `lib/state/`, one file per domain (`games_state.dart`, `downloads_state.dart`,
`gog_state.dart`, `gog_backend.dart`, `gogdl_backend.dart`, `launch_state.dart`, `proton_state.dart`,
`saves_state.dart`, `home_state.dart`), plus three supporting files that aren't domains themselves:
`bridge_stream.dart` (`guardBridgeStream`, which every `GogdlBackend` stream is wrapped in so that an
error thrown after `onDone`, within a short grace period, still arrives as a stream error instead of
being silently dropped), `emit_throttle.dart` (`ThrottledTaskBuffer`, which `DownloadsNotifier`,
`ProtonNotifier` and `SavesNotifier` each use to throttle high-frequency progress-event state
replacements to ~10Hz with a trailing flush, so the final value in a burst is never dropped) and
`shared_preferences_provider.dart`. Every domain follows the same shape:

- An immutable, read-only **State** class (`GamesState`, `DownloadsState`, ...) exposing getters only.
- A `Notifier<State>` subclass that is the *only* thing allowed to mutate state, always by
  constructing a new state object (`state = XState({...state.map, key: value})`) rather than mutating
  in place — mutating a `const {}` map in place has caused real crashes. The task/game objects held
  inside these states (`ActivityTask`, `SaveTask`, `ProtonTask`, `RunningGame`) are immutable too:
  every field is `final`, and updates go through a `copyWith` using an `_unset` sentinel object (not
  `null`) for nullable fields, so "argument omitted" (keep the existing value) can be distinguished
  from "argument explicitly passed as `null`" (clear the field) — same pattern as
  `GameConfig.copyWith`.
- A top-level `xStateProvider` (`Provider` or `NotifierProvider`) with an explicit `name:` for
  debugging.

`GamesNotifier`'s keystroke-driven setters (`setLaunchArgs`, `setEnvVars`, `setLaunchWrapper`) update
state immediately but debounce the SharedPreferences write by 500ms, since each call otherwise
re-encodes and writes the *whole* `games` JSON; `flushPendingPersist` commits a pending write early
and is called from `GameSettingsTab`'s `dispose`/game-switch and from the notifier's own
`ref.onDispose` — the latter reads a plain mirror field rather than `state`, since Riverpod forbids
touching `state`/`ref` from inside an `onDispose` callback.

`gogStateProvider` (`lib/state/gog_state.dart`) wraps a `GogBackend` (see "What this is" above); nearly
every other notifier reads it via `ref.read(gogStateProvider)`. Its methods follow a consistent
convention: try the backend call, log the failure via `logGogError` (`lib/common/gog_error.dart`,
which only prints in debug builds) and either `rethrow` or return `null`/empty — the same in debug
and release — callers are expected to handle `null` as "the operation failed."

`GogState.getOwnedGames` is filtered to real games by the bridge (`gogdl_flutter` v1.1.3+): DLC and
other non-game products the account owns no longer come back in the list. That filtering is
per-product, unordered and uncached upstream, so `GogState` caches the resolved list for the session
and sorts it before returning, invalidating the cache on failure or an empty result so a Retry
re-fetches instead of replaying a stale outcome.

**Backend streams are single-subscription.** Each `GogState` job-starting method (verification,
download, repair, Proton download, save download, save upload) starts a new backend job and returns
a fresh stream on every call — none of them are cached — so only the owning notifier
(`DownloadsNotifier`, `ProtonNotifier`, `SavesNotifier`) may ever `.listen()` to the stream it
requests, and must not request another one for the same key while the previous stream is still in
use. UI code must never listen to the raw backend stream directly — it reads live progress from the
corresponding State object (`DownloadsState.tasks`, `ProtonState.tasks`, ...), which the owning
notifier updates on every event.

**`sharedPreferencesProvider`** (`lib/state/shared_preferences_provider.dart`) must be overridden in
`main()` with an already-resolved `SharedPreferences` instance *before* `runApp` — notifiers that
persist to prefs (`GamesNotifier`, `ProtonNotifier`) load their persisted state synchronously inside
`build()`. Don't reintroduce an async `SharedPreferences.getInstance().then(...)` load path; that
previously raced app startup and let the UI read/clobber empty state.

### Proton / launching games

Games run under an app-managed Proton-GE (not system Steam). Filesystem layout is centralized in
`lib/common/app_paths.dart` (XDG-based, under `lumenDataDir()` = `$XDG_DATA_HOME/lumen` or
`$HOME/.local/share/lumen`):
- Proton releases extracted to `<lumenDataDir>/proton/<tag>`.
- Per-game Proton prefixes at `<lumenDataDir>/prefixes/<gameId>` (the actual Wine prefix is the `pfx`
  subdirectory — Proton creates it on first run).
- A shared fake Steam client dir at `<lumenDataDir>/steam`, passed as
  `STEAM_COMPAT_CLIENT_INSTALL_PATH` (mirrors how Lutris/Heroic/non-Steam Proton launchers work).

`LaunchNotifier.launchGame` (`lib/state/launch_state.dart`) follows gogdl-cli's `runner.rs` recipe: a
one-time `proton run wineboot` to initialize a fresh prefix, then `proton run <exe> <args>` with cwd
set to the executable's parent directory. The only env vars the tool itself injects are
`STEAM_COMPAT_CLIENT_INSTALL_PATH`/`STEAM_COMPAT_DATA_PATH` — no WINEPREFIX, no DXVK/winetricks setup.
If the game's `launchWrapper` config (`GameConfig.launchWrapper`) is non-empty, its tokens are
prepended to the `proton run <exe> <args>` invocation so the wrapper (e.g. `gamescope -f --`) becomes
the spawned process — mirroring Steam's launch-option wrappers. The wineboot init call is never
wrapped. This subsystem never talks to the bridge.

Game install directories are always user-chosen via `DirPicker` (never under `lumenDataDir()`).

### Cloud saves

Save sync is two whole-job bridge streams (`GogBackend.downloadSaves`/`uploadSaves`), not per-file
calls. The bridge resolves GOG's save locations itself from `prefix` + `installPath`, so Lumen has no
known-folder mapping of its own: `prefix` must be the Wine prefix that contains `drive_c`, which is
`<protonPrefixPath>/pfx` (not the Proton prefix root), and `installPath` backs `INSTALL`-relative
locations. There is no automatic conflict resolution or timestamp comparison — download vs. upload
are two explicit, user-triggered directions (`SavesNotifier.downloadSaves`/`uploadSaves`). The bridge
never retries, so the first failure aborts the whole job. Download progress has a job byte total up
front; upload only reports a file count up front, so `SaveTask.progress` is bytes for downloads and
files for uploads. Cloud-save support isn't queryable ahead of time: a game with none completes with
zero files (`SaveTask.isEmpty`), or errors if it declares no cloud storage.

### UI structure

`login_screen.dart` → `home_screen.dart` (top nav bar switches between `library`, `downloads`,
`settings` pages via `navBarItemProvider`, a `NavBarNotifier extends Notifier<NavBarItem>` in
`lib/state/home_state.dart` — the single source of truth for the selected tab; `NavBar` and
`HomeScreen` both watch it rather than keeping their own copy) → `library_page.dart` →
`game_details_view.dart`, which
tabs between Overview / Builds / Settings / DLC / Saves for a single game. `game_action_buttons.dart`
is the shared status-driven action row (Install/Import while not installed, Play/Running once
installed) reused in both the library hero and the game header.

Reusable presentational widgets live in `lib/components/`; theme constants (colors, decorations,
spacing, text styles) live in `lib/theme/` — dark theme only, `Onest` via `google_fonts`.
