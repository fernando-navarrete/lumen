# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Lumen is a Flutter desktop app (Linux only — see `linux/`, no other platform folders) that acts as a
GOG game library manager, downloader, and Proton launcher. All GOG API access, downloading,
verification/repair, save-cloud sync, and Proton-GE release fetching is delegated to a Rust bridge
consumed as the `gogdl_flutter` package (via `flutter_rust_bridge`, initialized with `RustLib.init()`
in `lib/main.dart`). That package is a private git dependency
(`ssh://git@thinkcentre.home:2200/gogdl/gogdl_flutter.git`), not published to pub.dev — its generated
API is what `lib/state/gog_state.dart` wraps.

## Commands

This project uses **fvm** (Flutter Version Management) — always prefix Flutter/Dart commands with
`fvm`, not the bare `flutter`/`dart` binaries, so the pinned SDK version from `.fvm/fvm_config.json`
is used.

```bash
fvm flutter pub get                        # install dependencies
fvm flutter analyze                        # static analysis / lints (flutter_lints)
fvm flutter test                            # run the full test suite
fvm flutter test test/downloads_state_test.dart          # run a single test file
fvm flutter test test/downloads_state_test.dart --name "startDownload does not throw"  # single test
fvm flutter run -d linux                    # run the app (only Linux target exists)
fvm flutter build linux                     # build the Linux release binary
```

## Architecture

### State management (Riverpod)

All app state lives in `lib/state/`, one file per domain (`games_state.dart`, `downloads_state.dart`,
`gog_state.dart`, `launch_state.dart`, `proton_state.dart`, `saves_state.dart`, `home_state.dart`).
Every domain follows the same shape:

- An immutable, read-only **State** class (`GamesState`, `DownloadsState`, ...) exposing getters only.
- A `Notifier<State>` subclass that is the *only* thing allowed to mutate state, always by
  constructing a new state object (`state = XState({...state.map, key: value})`) rather than mutating
  in place — mutating a `const {}` map in place has caused real crashes (see
  `test/downloads_state_test.dart`'s regression comment).
- A top-level `xStateProvider` (`Provider` or `NotifierProvider`) with an explicit `name:` for
  debugging.

`gogStateProvider` (`lib/state/gog_state.dart`) wraps the raw `Gog` bridge object; nearly every other
notifier reads it via `ref.read(gogStateProvider)` to talk to the Rust side. Its methods follow a
consistent convention: try the bridge call, `print` and either `rethrow` or return `null`/empty on
`kDebugMode` catch — callers are expected to handle `null` as "the operation failed."

**Bridge streams are single-subscription.** `GogState` caches one stream per gameId (verification,
download, repair) or per Proton tag (Proton download), so only the owning notifier
(`DownloadsNotifier`, `ProtonNotifier`) may ever `.listen()` to it. UI code must never listen to the
raw bridge stream directly — it reads live progress from the corresponding State object
(`DownloadsState.tasks`, `ProtonState.tasks`, ...), which the owning notifier updates on every event.

**Pause/resume/cancel** for downloads and repairs goes through a `DownloadControl` handle cached in
`GogState` per gameId (one job per game at a time). `DownloadsNotifier.pauseTask/resumeTask/cancelTask`
optimistically set the task's `jobStatus` string (`"pausing"`, `"cancelling"`, ...) before the bridge
stream itself reports the settled status.

**`sharedPreferencesProvider`** (`lib/state/shared_preferences_provider.dart`) must be overridden in
`main()` with an already-resolved `SharedPreferences` instance *before* `runApp` — notifiers that
persist to prefs (`GamesNotifier`, `ProtonNotifier`) load their persisted state synchronously inside
`build()`. Don't reintroduce an async `SharedPreferences.getInstance().then(...)` load path; that
previously raced app startup and let the UI read/clobber empty state.

`GameConfig.copyWith` (`games_state.dart`) uses an `_unset` sentinel object (not `null`) as the default
for nullable fields, so "argument omitted" (keep existing value) can be distinguished from "argument
explicitly passed as `null`" (clear the field).

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

Game install directories are always user-chosen via `DirPicker` (never under `lumenDataDir()`).

### Cloud saves

`lib/common/save_paths.dart` maps the bridge's Windows "known folder" keys (`Saved Games`,
`Documents`, `AppData/Roaming`, ...) onto paths inside a game's Wine prefix
(`<prefixPath>/pfx/drive_c/...`), except `INSTALLATION_PATH` which resolves to the game's actual
install directory. There is no automatic conflict resolution or timestamp comparison — download vs.
upload are two explicit, user-triggered directions (`SavesNotifier.downloadSaves`/`uploadSaves` in
`lib/state/saves_state.dart`).

### UI structure

`login_screen.dart` → `home_screen.dart` (top nav bar switches between `library`, `downloads`,
`settings` pages via `navBarItemProvider`) → `library_page.dart` → `game_details_view.dart`, which
tabs between Overview / Builds / Settings / DLC / Saves for a single game. `game_action_buttons.dart`
is the shared status-driven action row (Install/Import → Pause/Resume/Cancel while installing →
Play/Running once installed) reused in both the library hero and the game header.

Reusable presentational widgets live in `lib/components/`; theme constants (colors, decorations,
spacing, text styles) live in `lib/theme/` — dark theme only, `Onest` via `google_fonts`.

### Testing conventions

Tests mock the Rust bridge by implementing `Gog` with `noSuchMethod` and overriding only the specific
stream-returning methods under test (see `test/downloads_state_test.dart`), then override
`gogStateProvider` on a fresh `ProviderContainer` (`gogStateProvider.overrideWithValue(GogState(_FakeGog()))`).
Call `SharedPreferences.setMockInitialValues({})` in `setUp` for any test touching a notifier that
reads `sharedPreferencesProvider`.
