# Changelog

One `## X.Y.Z` section per tag; the release job publishes the tag's section as the release notes.
Versions before 1.5.0 are described in `devlog/` (one file per minor release, plus
`v1.0.x-bugfixes.md`).

## 1.5.2

### Changed

* No behaviour change. Internal cleanup: one byte formatter instead of two, and a stale comment removed.

## 1.5.1

### Changed

* No behaviour change. Confirmed that GOG's game summaries are plain text (HTML only appears in
  non-game records, which the library already filters out), and added a test that pins the Overview
  tab showing them verbatim.

## 1.5.0

First packaged release: an AppImage built and published by the release pipeline.

### Added

* AppImage (`Lumen-1.5.0-x86_64.AppImage` with a `.sha256`). GTK 3 and libsecret come from the host;
  it needs glibc 2.34 or newer and a Secret Service provider.
* Window icon, a 960×600 minimum window size, and a `.desktop` file and AppStream metadata.
* Keyboard focus and screen-reader semantics for buttons and cards (Tab, Enter and Space, with a
  focus outline).

### Changed

* The login screen shows a loader while the stored session restores instead of flashing the sign-in
  card, no longer advances its steps on a timer, accepts a pasted redirect URL, shows a specific
  message for a rejected code, and fits the minimum window size.
* The detail tabs share one responsive side-column width.
* Games launched from the AppImage no longer inherit `APPDIR`, `APPIMAGE`, `ARGV0` or `OWD`.
  "Open log" and the login URL now open through `xdg-open` (`url_launcher` is gone).
* gogdl_flutter `v1.5.0` (named progress fields, new login error kinds, one request for a game's
  image links, paged Proton releases).

### Known issues

* The GOG bridge panics at startup when the system has no CA certificate bundle.
* Only tested on Hyprland: the minimum window size and icon are untested on GNOME, KDE and X11.

### Upgrading

* The application ID is now `io.github.fernando_navarrete.Lumen`. Your settings are copied over on
  first start; the stored GOG token is not, so you sign in once.
