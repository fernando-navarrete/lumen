# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Lumen is a Flutter desktop app (Linux only — see `linux/`, no other platform folders) that acts as a
GOG game library manager, downloader, and Proton launcher.

**This is the `restart` branch.** All GOG API access, downloading, verification/repair, save-cloud
sync, and Proton-GE release fetching used to be delegated to a Rust bridge consumed as the
`gogdl_flutter` package (via `flutter_rust_bridge`). That package is being rebuilt from scratch (see
lumen-project's workspace-level `CLAUDE.md` for the "restart line" across all three repos), so this
branch has no dependency on it at all — `pubspec.yaml` has no `gogdl_flutter` entry, and nothing under
`lib/` imports it. In its place, `lib/state/gog_backend.dart` declares a `GogBackend` interface with
the same method set the old bridge exposed, and `lib/state/unimplemented_backend.dart` is the only
implementation: every data/stream method throws or emits `GogUnavailable`, and the auth/config methods
no-op successfully so login still falls through to `HomeScreen`. `lib/state/gog_state.dart` — the
facade nearly everything else talks to — is unchanged in shape; it now wraps `GogBackend` instead of
the bridge's `Gog`.

**Re-wiring a rebuilt bridge is meant to be one new file**: write a `RealGogBackend implements
GogBackend` that adapts the new bridge's API to this interface, and swap the constructor argument in
`gogStateProvider` (`lib/state/gog_state.dart`) from `UnimplementedBackend()` to it. No other file needs
to change. Bridge data types (`GameBuild`, `DownloadableProduct`, `ProtonRelease`, `SaveAuthIds`,
`CloudSaveConfig`, `CloudSaveFile`) and progress-stream payloads (`DownloadProgress`,
`VerificationProgress`, `RepairProgress`, `SaveTransferProgress`) are now app-owned plain-Dart classes
under `lib/models/`, not bridge-generated ones — a new backend adapts its own types into these, not the
other way around. `ProtonDownloadProgress` is the one exception: it stays the bridge's own freezed
union (`started`/`progress`/`extracted`), and `ProtonNotifier` (`lib/state/proton_state.dart`) adapts
it directly rather than going through an app-owned model.

## Commands

This project uses **fvm** (Flutter Version Management) — always prefix Flutter/Dart commands with
`fvm`, not the bare `flutter`/`dart` binaries, so the pinned SDK version from `.fvm/fvm_config.json`
is used.

```bash
fvm flutter pub get                        # install dependencies
fvm flutter analyze                        # static analysis / lints (flutter_lints)
fvm flutter run -d linux                    # run the app (only Linux target exists)
fvm flutter build linux                     # build the Linux release binary
```

There is no `test/` directory on this branch — it was deleted along with the bridge it mocked. Add
tests back as features are rebuilt against `GogBackend`.

## Architecture

### State management (Riverpod)

All app state lives in `lib/state/`, one file per domain (`games_state.dart`, `downloads_state.dart`,
`gog_state.dart`, `gog_backend.dart`, `unimplemented_backend.dart`, `launch_state.dart`,
`proton_state.dart`, `saves_state.dart`, `home_state.dart`). Every domain follows the same shape:

- An immutable, read-only **State** class (`GamesState`, `DownloadsState`, ...) exposing getters only.
- A `Notifier<State>` subclass that is the *only* thing allowed to mutate state, always by
  constructing a new state object (`state = XState({...state.map, key: value})`) rather than mutating
  in place — mutating a `const {}` map in place has caused real crashes.
- A top-level `xStateProvider` (`Provider` or `NotifierProvider`) with an explicit `name:` for
  debugging.

`gogStateProvider` (`lib/state/gog_state.dart`) wraps a `GogBackend` (see "What this is" above); nearly
every other notifier reads it via `ref.read(gogStateProvider)`. Its methods follow a consistent
convention: try the backend call, `print` and either `rethrow` or return `null`/empty on `kDebugMode`
catch — callers are expected to handle `null` as "the operation failed." This convention is what makes
`UnimplementedBackend` safe to ship: every call site already tolerates failure.

**Backend streams are single-subscription.** `GogState` caches one stream per gameId (verification,
download, repair) or per Proton tag (Proton download), so only the owning notifier
(`DownloadsNotifier`, `ProtonNotifier`) may ever `.listen()` to it. UI code must never listen to the
raw backend stream directly — it reads live progress from the corresponding State object
(`DownloadsState.tasks`, `ProtonState.tasks`, ...), which the owning notifier updates on every event.

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
This subsystem never talked to the bridge and is unaffected by the restart.

Game install directories are always user-chosen via `DirPicker` (never under `lumenDataDir()`).

### Cloud saves

`lib/common/save_paths.dart` maps GOG's Windows "known folder" keys (`Saved Games`, `Documents`,
`AppData/Roaming`, ...) onto paths inside a game's Wine prefix (`<prefixPath>/pfx/drive_c/...`), except
`INSTALLATION_PATH` which resolves to the game's actual install directory. There is no automatic
conflict resolution or timestamp comparison — download vs. upload are two explicit, user-triggered
directions (`SavesNotifier.downloadSaves`/`uploadSaves` in `lib/state/saves_state.dart`).

### UI structure

`login_screen.dart` → `home_screen.dart` (top nav bar switches between `library`, `downloads`,
`settings` pages via `navBarItemProvider`) → `library_page.dart` → `game_details_view.dart`, which
tabs between Overview / Builds / Settings / DLC / Saves for a single game. `game_action_buttons.dart`
is the shared status-driven action row (Install/Import while not installed, Play/Running once
installed) reused in both the library hero and the game header.

Reusable presentational widgets live in `lib/components/`; theme constants (colors, decorations,
spacing, text styles) live in `lib/theme/` — dark theme only, `Onest` via `google_fonts`.
